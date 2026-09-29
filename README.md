# manspick-os

> **초안 (2026-09-29)** — Figma 화면 확정 전에 만든 스키마·뼈대입니다. 화면 검토가 끝나면 `supabase/migrations/0001_init.sql`과 `src/`를 확정 화면에 맞춰 수정한 뒤 사용합니다. 그 전까지 이 코드를 기준으로 삼지 마세요.

맨즈픽 운영 OS. 설계 원본은 Figma 「Manspick OS — Customer UI」, 확정 규칙은 `docs/canonical.md`, 작업 규칙은 `CLAUDE.md`.

```bash
cp .env.example .env.local   # Supabase 키 입력
npm install
npm run dev
```

- `supabase/migrations/0001_init.sql` — 스키마·RLS. Supabase SQL Editor에 적용.
- `src/app/(customer)/c/[token]` — 고객 화면 (링크 + 전화번호 뒤 4자리)
- `src/app/(internal)/{admin,director,retoucher}` — 내부 화면 (이메일 로그인)
- `src/lib/status.ts` — 상태값 30 · 7단계 매핑 (DB enum과 1:1)
