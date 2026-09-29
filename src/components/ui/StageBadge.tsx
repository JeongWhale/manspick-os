import { STAGES, type Stage } from "@/lib/status";

const COLOR: Record<Stage, string> = {
  1: "text-stage-1 bg-stage-1/15", 2: "text-stage-2 bg-stage-2/15", 3: "text-stage-3 bg-stage-3/15",
  4: "text-stage-4 bg-stage-4/15", 5: "text-stage-5 bg-stage-5/15", 6: "text-stage-6 bg-stage-6/15", 7: "text-stage-7 bg-stage-7/15",
};

export function StageBadge({ stage }: { stage: Stage }) {
  const s = STAGES[stage - 1];
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-label-s font-medium ${COLOR[stage]}`}>
      <span className="size-1.5 rounded-full bg-current" />
      {s.n} · {s.label}
    </span>
  );
}
