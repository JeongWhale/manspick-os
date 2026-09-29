import type { ButtonHTMLAttributes } from "react";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "kakao"; full?: boolean };

const V = {
  primary: "bg-accent-500 text-text-on-accent hover:bg-accent-600",
  secondary: "bg-transparent text-text-primary border border-border-strong hover:bg-bg-elevated",
  kakao: "bg-kakao text-[#191919] hover:brightness-95",
};

export function Button({ variant = "primary", full, className = "", ...rest }: Props) {
  return (
    <button
      className={`h-13 px-5 rounded-lg text-label font-semibold transition disabled:opacity-40 disabled:cursor-not-allowed ${V[variant]} ${full ? "w-full" : ""} ${className}`}
      {...rest}
    />
  );
}
