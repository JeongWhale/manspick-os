-- Manspick OS · 초기 스키마 v0.1 (2026-09-29)
-- 기준: docs/canonical.md v1.3, Figma D3 API 초안
-- 고객은 로그인하지 않는다. 고객 화면은 Next.js 서버(service_role)가 access_token + phone_last4를 검증한 뒤 대신 조회한다.
-- 내부 사용자(admin/staff/director/retoucher)는 Supabase Auth 이메일 로그인 + RLS.

create extension if not exists "pgcrypto";

-- ───────────────────────── enums
create type user_role as enum ('admin', 'staff', 'director', 'retoucher');
create type package_code as enum ('원', '하이브리드', '올데이');
create type payment_channel as enum ('transfer', 'kmong', 'frip', 'soomgo', 'smartstore', 'unpaid');
create type select_by as enum ('customer', 'director');
create type slot_state as enum ('open', 'held', 'locked', 'blocked');
create type file_type as enum ('원본', '셀렉후보', '보정본', '최종본', '후기보상원본');
create type retouch_state as enum ('assigned', 'in_progress', 'uploaded', 'revision', 'done');
create type claim_state as enum ('submitted', 'confirmed', 'granted', 'rejected');

-- 내부 상태값 30 (Canonical v1.3). 순서 = 허용 전이 순서
create type customer_status as enum (
  '신규 문의', '옵션 확인중', '옵션 선택 완료',                                                         -- stage 1
  '설문 작성 대기', '설문 제출 완료',                                                                    -- stage 2
  '디렉터 자동 배정 완료', '캘린더 선택 대기', '고객 일정 선택 완료', '결제 확인 대기',                  -- stage 3
  '촬영일 확정 안내 발송 완료', '촬영 준비중', '전날 리마인드 발송 완료', '촬영 당일 대기',              -- stage 4
  '고객 도착', '부가서비스 진행중', '의상 점검 완료', '촬영중', '중간 확인 완료', '촬영 완료',            -- stage 5
  '셀렉 대기', '셀렉 완료', '보정 배정 완료', '보정중', '전달 완료',                                      -- stage 6
  '후기 요청 발송', '후기 확인 대기', '후기 확인 완료', '원본 전달 대기', '원본 전달 완료', '후속관리중'  -- stage 7
);

-- status → 고객 7단계
create or replace function stage_of(s customer_status) returns smallint language sql immutable as $$
  select case
    when s in ('신규 문의','옵션 확인중','옵션 선택 완료') then 1
    when s in ('설문 작성 대기','설문 제출 완료') then 2
    when s in ('디렉터 자동 배정 완료','캘린더 선택 대기','고객 일정 선택 완료','결제 확인 대기') then 3
    when s in ('촬영일 확정 안내 발송 완료','촬영 준비중','전날 리마인드 발송 완료','촬영 당일 대기') then 4
    when s in ('고객 도착','부가서비스 진행중','의상 점검 완료','촬영중','중간 확인 완료','촬영 완료') then 5
    when s in ('셀렉 대기','셀렉 완료','보정 배정 완료','보정중','전달 완료') then 6
    else 7 end::smallint
$$;

-- ───────────────────────── 내부 사용자
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null,
  name text not null,
  email text not null unique,
  regions text[] default '{}',            -- director
  weekly_capacity int,                    -- director
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ───────────────────────── 상품
create table packages (
  code package_code primary key,
  price int not null,
  original_price int,
  outfits int not null,
  duration_min int not null,
  retouch_count int not null,
  raw_count_label text,
  base_level int not null default 1,      -- 난이도 하1 중2 상3
  includes text[] not null default '{}',
  description text,
  active boolean not null default true
);
insert into packages values
 ('원',       85000, 120000, 1,  90, 5,  '300장+', 1, '{}', null, true),
 ('하이브리드',160000, 210000, 2, 120, 7,  '500장+', 2, '{}', null, true),
 ('올데이',   500000, 890000, 4, 300, 12, '700장+', 3, '{}', null, true);

create table addons (
  id text primary key,                    -- hair, clothes-rental, clothes-brand, dslr, ai, shopping, lecture
  name text not null,
  price int not null,
  per_outfit boolean not null default false,
  level_weight int not null default 0,
  template_key text,
  active boolean not null default true,
  sort int not null default 0
);
insert into addons (id,name,price,per_outfit,level_weight,sort) values
 ('hair','헤어 & 메이크업',70000,false,1,1),
 ('clothes-rental','인플루언서 의류 대여',25000,true,1,2),
 ('clothes-brand','브랜드 1코디 제작',50000,true,1,3),
 ('dslr','DSLR 스냅 촬영',120000,false,2,4),
 ('ai','AI 프로필 2장',70000,false,0,5),
 ('shopping','오프라인 동행쇼핑',100000,false,2,6),
 ('lecture','스마트폰 사진 강의',50000,false,0,7);

create table director_capabilities (
  director_id uuid references profiles(id) on delete cascade,
  addon_id text references addons(id) on delete cascade,
  primary key (director_id, addon_id)
);

-- 보정가 요일 규칙: 촬영일 요일(0=일 … 6=토) → 보정가
create table retoucher_rules (
  dow smallint primary key check (dow between 0 and 6),
  retoucher_id uuid not null references profiles(id)
);

-- ───────────────────────── 고객 (옵션 선택 + 기본정보 입력 시 생성)
create table customers (
  id uuid primary key default gen_random_uuid(),
  access_token text not null unique default replace(replace(rtrim(encode(gen_random_bytes(18), 'base64'), '='), '+', '-'), '/', '_'),
  name text not null,
  phone text not null,
  phone_last4 text generated always as (right(regexp_replace(phone, '\D', '', 'g'), 4)) stored,
  region text, age int, job text, kakao_nick text,
  status customer_status not null default '옵션 선택 완료',
  stage smallint generated always as (stage_of(status)) stored,
  package package_code not null,
  addon_ids text[] not null default '{}',
  addon_qty jsonb not null default '{}',
  total_amount int not null,
  payment_channel payment_channel not null default 'unpaid',
  payment_amount int,
  payment_confirmed_at timestamptz,
  payment_confirmed_by uuid references profiles(id),
  consent_privacy boolean not null default false,
  consent_notice boolean not null default false,
  consent_marketing boolean not null default false,
  director_id uuid references profiles(id),
  retoucher_id uuid references profiles(id),
  select_by select_by,
  select_by_final select_by,
  select_change_reason text,
  inquiry_channel text default 'kakao',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index customers_phone_active on customers (phone) where status <> '후속관리중';
create index customers_status_idx on customers (status);
create index customers_director_idx on customers (director_id);

create table surveys (
  customer_id uuid primary key references customers(id) on delete cascade,
  answers jsonb not null default '{}',    -- 목적·용도·무드·고민·보정정도·의상·체형 등
  photo_paths text[] not null default '{}',  -- Supabase Storage (유일 예외)
  page_done smallint not null default 0,  -- 임시 저장 (4페이지)
  submitted_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ───────────────────────── 배정 · 일정
create table director_assignments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  director_id uuid not null references profiles(id),
  scores jsonb not null,                  -- {level:{...}, schedule:{...}, load:{...}, region:{...}, candidates:[...]}
  manual boolean not null default false,
  reason text,
  decided_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

create table calendar_slots (
  id uuid primary key default gen_random_uuid(),
  director_id uuid not null references profiles(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  state slot_state not null default 'open',
  customer_id uuid references customers(id),
  held_until timestamptz,                 -- 결제 확인 대기 24h
  memo text,
  unique (director_id, starts_at)
);
create index slots_open_idx on calendar_slots (director_id, starts_at) where state = 'open';

create table bookings (
  customer_id uuid primary key references customers(id) on delete cascade,
  slot_id uuid not null unique references calendar_slots(id),
  director_id uuid not null references profiles(id),
  place text not null default '맨즈픽 스튜디오',
  prep_checks jsonb not null default '{}',   -- 고객 C4 확인 체크 (참고값)
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create table shoot_sessions (
  customer_id uuid primary key references customers(id) on delete cascade,
  checklist jsonb not null default '{}',  -- {arrived:ts, addon:ts, icebreak:ts, order:ts, outfit:ts, shoot:ts, midcheck:ts, wrap:ts}
  notes text,
  completed_at timestamptz
);

-- ───────────────────────── 결과물
create table file_links (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  type file_type not null,
  url text not null,
  version int not null default 1,
  uploaded_by uuid references profiles(id),
  customer_visible boolean not null default false,
  created_at timestamptz not null default now(),
  unique (customer_id, type, version)
);

create table selections (
  customer_id uuid primary key references customers(id) on delete cascade,
  candidate_count int,
  pick_limit int not null,
  picked_ids text[] not null default '{}',
  requests jsonb not null default '[]',   -- [{by:'customer'|'director', cut:'DSC_0203', text:'…'}]
  submitted_at timestamptz
);

create table retouchings (
  customer_id uuid primary key references customers(id) on delete cascade,
  retoucher_id uuid not null references profiles(id),
  state retouch_state not null default 'assigned',
  due_at timestamptz,
  preferences jsonb not null default '{}', -- 설문에서 추출: 피부·체형·색감·배경 0~5
  revision int not null default 0,
  assigned_at timestamptz not null default now(),
  done_at timestamptz
);

-- ───────────────────────── 템플릿 · 기록
create table message_templates (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  title text not null,
  body text not null,
  stage smallint,
  status customer_status,
  conditions jsonb not null default '{}', -- {package:[...], addons:[...], sender:['staff','director']}
  next_status customer_status,            -- 발송 완료 체크 시 자동 전이
  active boolean not null default true,
  sort int not null default 0,
  updated_by uuid references profiles(id),
  updated_at timestamptz not null default now()
);

create table message_logs (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  template_id uuid not null references message_templates(id),
  sent_by uuid not null references profiles(id),
  sent_at timestamptz not null default now()
);

create table timeline_events (
  id bigserial primary key,
  customer_id uuid not null references customers(id) on delete cascade,
  type text not null,                     -- status_change | assignment | booking | message | file | note | claim
  from_status customer_status,
  to_status customer_status,
  actor uuid references profiles(id),     -- null = customer / system
  actor_kind text not null default 'staff', -- staff | director | retoucher | customer | system
  reason text,
  payload jsonb,
  created_at timestamptz not null default now()
);
create index timeline_customer_idx on timeline_events (customer_id, created_at desc);

create table notes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  author uuid not null references profiles(id),
  body text not null,
  created_at timestamptz not null default now()
);

-- ───────────────────────── 후속 이벤트
create table follow_up_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  condition text,
  benefit text,
  starts_on date, ends_on date,
  template_id uuid references message_templates(id),
  active boolean not null default true
);

create table campaign_claims (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references follow_up_campaigns(id),
  customer_id uuid not null references customers(id) on delete cascade,
  evidence text,
  state claim_state not null default 'submitted',
  handled_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  handled_at timestamptz
);

-- ───────────────────────── 상태 전이 (순서대로만; 예외는 staff + reason)
create or replace function next_status(s customer_status) returns customer_status language sql immutable as $$
  select (enum_range(s, null))[2]
$$;

create or replace function change_status(p_customer uuid, p_to customer_status, p_actor uuid, p_actor_kind text, p_reason text default null)
returns void language plpgsql security definer as $$
declare v_from customer_status; v_role user_role;
begin
  select status into v_from from customers where id = p_customer for update;
  if p_to = v_from then return; end if;
  if p_to <> next_status(v_from) then
    select role into v_role from profiles where id = p_actor;
    if v_role is distinct from 'admin' and v_role is distinct from 'staff' then
      raise exception '순차 전이만 허용됩니다 (% → %)', v_from, p_to;
    end if;
    if p_reason is null or length(trim(p_reason)) = 0 then
      raise exception '예외 전이는 사유가 필요합니다';
    end if;
  end if;
  update customers set status = p_to, updated_at = now() where id = p_customer;
  insert into timeline_events (customer_id, type, from_status, to_status, actor, actor_kind, reason)
  values (p_customer, 'status_change', v_from, p_to, p_actor, p_actor_kind, p_reason);
end $$;

-- ───────────────────────── 보정가 마스킹 뷰 (이름·연락처·설문 제외)
-- security_definer(기본): 뷰 소유자 권한으로 customers를 읽되 auth.uid() 필터로 본인 작업만. 보정가는 customers 직접 조회 불가
create view retoucher_jobs_masked as
select r.customer_id,
       'MP-' || to_char(b_slot.starts_at, 'MMDD') || '-' || right(r.customer_id::text, 2) as job_code,
       c.package, r.state, r.due_at, r.preferences, r.revision,
       s.picked_ids, s.requests,
       (select url from file_links f where f.customer_id = r.customer_id and f.type = '원본' order by version desc limit 1) as raw_url,
       (select url from file_links f where f.customer_id = r.customer_id and f.type = '셀렉후보' order by version desc limit 1) as candidates_url,
       c.director_id
from retouchings r
join customers c on c.id = r.customer_id
left join selections s on s.customer_id = r.customer_id
left join bookings b on b.customer_id = r.customer_id
left join calendar_slots b_slot on b_slot.id = b.slot_id
where r.retoucher_id = auth.uid();

-- ───────────────────────── RLS
create or replace function my_role() returns user_role language sql stable security definer as $$
  select role from profiles where id = auth.uid()
$$;
create or replace function is_staff() returns boolean language sql stable as $$
  select my_role() in ('admin','staff')
$$;

alter table profiles enable row level security;
create policy profiles_read on profiles for select using (auth.uid() is not null);
create policy profiles_admin on profiles for all using (my_role() = 'admin');

alter table packages enable row level security;
alter table addons enable row level security;
alter table director_capabilities enable row level security;
alter table retoucher_rules enable row level security;
create policy catalog_read_packages on packages for select using (true);
create policy catalog_read_addons on addons for select using (true);
create policy catalog_read_caps on director_capabilities for select using (auth.uid() is not null);
create policy catalog_read_rules on retoucher_rules for select using (auth.uid() is not null);
create policy catalog_admin_packages on packages for all using (my_role() = 'admin');
create policy catalog_admin_addons on addons for all using (my_role() = 'admin');
create policy catalog_admin_caps on director_capabilities for all using (my_role() = 'admin');
create policy catalog_admin_rules on retoucher_rules for all using (my_role() = 'admin');

-- 고객 본체: staff 전체 / director 본인 배정만 / retoucher 직접 접근 불가 (뷰만)
alter table customers enable row level security;
create policy customers_staff on customers for all using (is_staff());
create policy customers_director on customers for select using (my_role() = 'director' and director_id = auth.uid());
create policy customers_director_update on customers for update using (my_role() = 'director' and director_id = auth.uid());

alter table surveys enable row level security;
create policy surveys_staff on surveys for all using (is_staff());
create policy surveys_director on surveys for select using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));

alter table director_assignments enable row level security;
create policy assign_staff on director_assignments for all using (is_staff());
create policy assign_director on director_assignments for select using (director_id = auth.uid());

alter table calendar_slots enable row level security;
create policy slots_staff on calendar_slots for all using (is_staff());
create policy slots_director on calendar_slots for all using (director_id = auth.uid());

alter table bookings enable row level security;
create policy bookings_staff on bookings for all using (is_staff());
create policy bookings_director on bookings for select using (director_id = auth.uid());

alter table shoot_sessions enable row level security;
create policy shoot_staff on shoot_sessions for all using (is_staff());
create policy shoot_director on shoot_sessions for all using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));

alter table file_links enable row level security;
create policy files_staff on file_links for all using (is_staff());
create policy files_director on file_links for all using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));
create policy files_retoucher_read on file_links for select using (type in ('원본','셀렉후보') and exists (select 1 from retouchings r where r.customer_id = file_links.customer_id and r.retoucher_id = auth.uid()));
create policy files_retoucher_write on file_links for insert with check (type = '보정본' and exists (select 1 from retouchings r where r.customer_id = file_links.customer_id and r.retoucher_id = auth.uid()));

alter table selections enable row level security;
create policy sel_staff on selections for all using (is_staff());
create policy sel_director on selections for all using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));
create policy sel_retoucher on selections for select using (exists (select 1 from retouchings r where r.customer_id = selections.customer_id and r.retoucher_id = auth.uid()));

alter table retouchings enable row level security;
create policy ret_staff on retouchings for all using (is_staff());
create policy ret_director on retouchings for select using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));
create policy ret_self on retouchings for all using (retoucher_id = auth.uid());

alter table message_templates enable row level security;
create policy tpl_read on message_templates for select using (auth.uid() is not null);
create policy tpl_admin on message_templates for all using (my_role() = 'admin');

alter table message_logs enable row level security;
create policy logs_staff on message_logs for all using (is_staff());
create policy logs_director on message_logs for all using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));

alter table timeline_events enable row level security;
create policy tl_staff on timeline_events for all using (is_staff());
create policy tl_director on timeline_events for select using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));

alter table notes enable row level security;
create policy notes_staff on notes for all using (is_staff());
create policy notes_director on notes for all using (exists (select 1 from customers c where c.id = customer_id and c.director_id = auth.uid()));

alter table follow_up_campaigns enable row level security;
alter table campaign_claims enable row level security;
create policy camp_read on follow_up_campaigns for select using (auth.uid() is not null);
create policy camp_admin on follow_up_campaigns for all using (my_role() = 'admin');
create policy claims_staff on campaign_claims for all using (is_staff());

-- Storage: 설문 사진 버킷 (비공개, 서버만 업로드)
insert into storage.buckets (id, name, public) values ('survey-photos', 'survey-photos', false) on conflict do nothing;
create policy survey_photos_staff on storage.objects for select using (bucket_id = 'survey-photos' and (is_staff() or my_role() = 'director'));
