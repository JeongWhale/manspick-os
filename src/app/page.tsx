import Link from "next/link";

export default function Home() {
  return (
    <main className="flex-1 flex items-center justify-center p-6">
      <div className="text-center space-y-4">
        <p className="font-display text-overline tracking-[0.12em] text-text-accent">MANSPICK OS</p>
        <h1 className="text-h1 font-bold">운영 플랫폼</h1>
        <p className="text-body text-text-secondary">고객은 카카오채널로 받은 링크로 들어옵니다.</p>
        <Link href="/login" className="inline-block text-label-s text-text-tertiary underline">내부 로그인</Link>
      </div>
    </main>
  );
}
