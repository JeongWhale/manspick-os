# ADR-001 기술 스택

- 상태: 확정 (2026-09-29)
- 결정자: 대표

## 맥락
월 60건 이상, 디렉터 3명 · 보정가 2명 · 대표 1명. 개발은 대표 + AI. 서버가 없는 정적 사이트(manspick.kr)는 그대로 두고 OS는 별도 제품으로 만든다.

## 결정
| 영역 | 선택 | 이유 |
|---|---|---|
| 프론트/서버 | Next.js App Router, TypeScript | 고객(모바일 웹)·내부(데스크톱)·디렉터(모바일)를 한 레포에서. Server Actions로 API 레이어 최소화 |
| DB · 인증 · 파일 | Supabase (Postgres, Auth, RLS, Storage) | 역할별 권한을 RLS로 DB에서 강제. 보정가 마스킹·디렉터 본인 배정만 조회가 정책 한 줄 |
| 배포 | Vercel + Supabase 클라우드 | 운영 부담 없음. 백업은 Supabase 일일 백업 + 주 1회 수동 export |
| 고객 인증 | access_token URL + phone_last4 | 회원가입 없음. 카카오 로그인은 심사 부담으로 2차 |
| 직원 인증 | Supabase Auth 이메일 로그인, `users.role` = admin / staff / director / retoucher | |
| 외부 연동 | 없음 | 카톡은 복붙, 드라이브는 링크 문자열, 결제는 수동 확인 |

## 거부한 대안
- 노코드(Softr · Bubble): 슬롯 잠금·보정가 마스킹·자동 배정 로직 표현이 어려움.
- 사이트 레포에 합치기: 정적 사이트와 운영 앱은 배포 주기·권한이 다름.
- Firebase: RLS에 해당하는 행 단위 권한이 약함.

## 결과
- Figma D3 API 초안 → `docs/api.md`로 이관 후 Server Actions / Route Handlers로 구현.
- 고객 URL 예: `https://<os-domain>/c/<access_token>` (도메인 미정).
