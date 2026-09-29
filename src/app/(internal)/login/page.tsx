import { Button } from "@/components/ui/Button";

// 내부 로그인 — 회사 이메일(@manspick.co.kr) 매직링크. Supabase Auth 연결은 키 등록 후.
export default function Login() {
  return (
    <main className="flex-1 grid place-items-center p-6">
      <form className="w-full max-w-sm space-y-4">
        <h1 className="text-h2 font-bold">내부 로그인</h1>
        <input name="email" type="email" placeholder="이름@manspick.co.kr" className="w-full h-12 rounded-md bg-bg-elevated border border-border-subtle px-4 text-body" />
        <Button full type="submit">로그인 링크 받기</Button>
      </form>
    </main>
  );
}
