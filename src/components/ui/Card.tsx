import type { HTMLAttributes } from "react";

export function Card({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`rounded-lg bg-bg-surface border border-border-subtle p-4 ${className}`} {...rest} />;
}
