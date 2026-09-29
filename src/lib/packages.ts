// docs/canonical.md — 패키지 3종만. 표기 정규화는 여기서만.
export const PACKAGES = ["원", "하이브리드", "올데이"] as const;
export type PackageCode = (typeof PACKAGES)[number];

const ALIASES: Record<string, PackageCode> = {
  ONE: "원", one: "원",
  HYBRID: "하이브리드", hybrid: "하이브리드",
  PREMIUM: "올데이", "ALL DAY": "올데이", allday: "올데이",
};
export function normalizePackage(input: string): PackageCode {
  if ((PACKAGES as readonly string[]).includes(input)) return input as PackageCode;
  const hit = ALIASES[input.trim()];
  if (!hit) throw new Error(`알 수 없는 패키지 표기: ${input}`);
  return hit;
}

export type PaymentChannel = "transfer" | "kmong" | "frip" | "soomgo" | "smartstore" | "unpaid";
export const PAYMENT_CHANNEL_LABEL: Record<PaymentChannel, string> = {
  transfer: "계좌이체", kmong: "크몽", frip: "프립", soomgo: "숨고", smartstore: "스마트스토어", unpaid: "아직 결제 전",
};
