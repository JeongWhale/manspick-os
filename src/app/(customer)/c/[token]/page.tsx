import { STAGE_TODO, STAGES } from "@/lib/status";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

// C0 진행 상태 홈 — 뼈대. 인증(token + 뒤 4자리)은 다음 단계에서 verifyCustomerToken으로 연결.
export default async function CustomerHome({ params }: PageProps<"/c/[token]">) {
  const { token } = await params;
  const stage = 4 as const; // TODO: verifyCustomerToken(token) → customer.stage
  return (
    <main className="mx-auto w-full max-w-[390px] flex-1 flex flex-col">
      <header className="flex items-center justify-between px-6 h-14 border-b border-border-subtle">
        <span className="font-display font-bold tracking-tight">MANSPICK</span>
        <span className="text-caption text-text-tertiary">문의하기</span>
      </header>
      <section className="p-6 space-y-5">
        <div className="space-y-2">
          <p className="font-display text-overline tracking-[0.12em] text-text-accent">MY SHOOT</p>
          <h1 className="text-h1 font-bold">{STAGE_TODO[stage]}</h1>
          <p className="text-body text-text-secondary">지금 하실 일은 하나예요. 나머지는 저희가 준비할게요.</p>
        </div>
        <Card className="bg-bg-accent-tint border-border-accent space-y-3">
          <p className="text-h3 font-semibold">촬영 준비 확인</p>
          <Button full>준비 안내 이어서 보기</Button>
        </Card>
        <Card className="space-y-0">
          {STAGES.map((s) => (
            <div key={s.n} className="flex items-center gap-3 py-2.5">
              <span className={`size-6 rounded-full grid place-items-center text-caption ${s.n < stage ? "bg-success/15 text-success" : s.n === stage ? "bg-accent-500 text-text-on-accent" : "bg-bg-elevated text-text-tertiary"}`}>{s.n}</span>
              <span className={`flex-1 text-body ${s.n === stage ? "font-semibold" : s.n < stage ? "text-text-tertiary" : "text-text-secondary"}`}>{s.label}</span>
              <span className="text-caption text-text-tertiary">{s.n < stage ? "완료" : s.n === stage ? "진행 중" : ""}</span>
            </div>
          ))}
        </Card>
        <p className="text-caption text-text-tertiary text-center">token: {token.slice(0, 6)}…</p>
      </section>
      <footer className="mt-auto p-6 border-t border-border-subtle">
        <Button variant="kakao" full>카카오채널로 문의하기</Button>
      </footer>
    </main>
  );
}
