# supabase/

- `migrations/0001_init.sql` — 스키마 v0.1. 테이블 21개, 상태 enum 30, `change_status()` 전이 함수, `retoucher_jobs_masked` 뷰, 역할별 RLS.
- 적용: Supabase 대시보드 SQL Editor에 붙여넣기, 또는 `supabase db push` (CLI 연결 후).
- 고객 화면은 RLS를 타지 않는다. Next.js 서버가 `service_role`로 `customers.access_token` + `phone_last4`를 검증한 뒤 대신 읽고 쓴다. `anon` 키로는 아무 테이블도 읽을 수 없어야 한다.
- 시드: `profiles`는 Auth에 6명(@manspick.co.kr) 초대 후 role만 채운다. `retoucher_rules`는 월·화 → 신민정, 수~일 → 최경선.
