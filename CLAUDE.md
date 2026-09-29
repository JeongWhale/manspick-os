# Manspick OS

남성 프로필 촬영 스튜디오 맨즈픽의 운영 OS. 고객·직원·디렉터·보정가가 한 흐름 안에서 움직인다.
확정값의 단일 출처는 `docs/canonical.md`이며 노션 「Canonical 규칙」 페이지와 동기화한다. 이 파일과 충돌하면 canonical.md가 우선한다.

## 스택 (ADR-001)
- Next.js (App Router) + TypeScript
- Supabase: Postgres · Auth · RLS · Storage
- Vercel 배포
- 개발: 대표 + Claude Code. 하루 단위 결정 → 구현 → 직접 써보기 루프.

## 절대 규칙
- 패키지명은 `원 / 하이브리드 / 올데이` 3개만. 코드 상수도 이 한글 표기를 기준으로 하고 `ONE / HYBRID / PREMIUM(ALL DAY)`은 입력 정규화에서만 매핑한다.
- 고객 상태는 `docs/canonical.md`의 상태값 목록만 쓴다. 새 상태값을 코드에서 만들지 않는다.
- 고객은 7단계(`stage`)만 본다. 내부 상태값(`status`)은 고객 화면에 절대 노출하지 않는다.
- 모든 상태 변경은 `timeline_events`에 (from, to, actor, reason) 기록. 되돌리기·건너뛰기는 reason 필수.
- 보정가에게는 셀렉 컷 · 요청사항 · 보정 선호도만 보인다. 이름·연락처·설문 상세는 RLS로 차단하고, 뷰 이름은 `retoucher_jobs_masked`.
- 파일은 외부 드라이브 링크 문자열로만 저장한다. 유일한 예외는 설문 사진(Supabase Storage).
- 카카오채널 자동 발송 없음. 템플릿은 복사 + "발송 완료" 체크(`message_logs`)로만 기록한다.
- 결제(PG) 연동 없음. 고객이 `payment_channel`(kmong / frip / soomgo / smartstore / transfer / unpaid)과 `payment_amount`를 입력하고, 직원이 일정 확정 전 `payment_confirmed_at`을 체크한다. 그 전까지 상태는 `결제 확인 대기`, 슬롯은 24시간 임시 잠금.
- 상태 전이는 `lib/transitions.ts`의 허용 표대로만. 표 밖 전이는 role ∈ {admin, staff} + reason 필수.
- 보정가 배정은 촬영일 요일 규칙(`retoucher_rules` 테이블: 월·화 → 신민정, 수~일 → 최경선). 하드코딩하지 않는다.
- 고객 인증은 `access_token`(URL) + 전화번호 뒤 4자리. 세션·회원가입 없음.

## 디렉터 자동 배정
설문 제출 즉시 실행하고 시스템이 확정한다. 우선순위: 난이도 → 가능 일정 → 이번 주 업무량 → 지역.
점수는 `director_assignments.scores`에 저장하고, 수동 변경은 reason 필수.

## 디렉터리 (예정)
```
app/            Next.js 라우트 — (customer)/ (admin)/ (director)/ (retoucher)/
lib/            supabase client, 상태 전이, 배정 알고리즘
supabase/       migrations, RLS policies, seed
docs/           canonical.md, adr/, api.md (Figma D3에서 이관)
```

## 설계 원본
- 화면 23개 · 유저플로우 · 기능명세 · API 초안: Figma 「Manspick OS — Customer UI」
  (페이지 01 Customer / 06 Internal / D1 / D2 / D3). 화면 ID(C1-a, I-3, M-1)를 커밋 메시지와 PR에 그대로 쓴다.
- 결정 이력: 노션 「의사결정 로그」

## 작업 방식
- 수직 슬라이스 우선: C1 → C2 → 배정 → C3 → I-1 · I-2 · 템플릿 복사가 실제 고객 1명을 통과할 때까지 다른 화면을 만들지 않는다.
- 새 테이블·컬럼은 먼저 `supabase/migrations`에, 그 다음 타입 생성, 그 다음 UI.
- 테스트는 D2 기능명세의 "상태 변화" 열을 그대로 케이스로 쓴다.
- 커밋 메시지는 한국어, `[C1-a] 옵션 선택 화면 골격` 형식.
