import { createClient } from "@supabase/supabase-js";

/**
 * service_role 클라이언트. 고객 화면(/c/[token]) 전용 — RLS 우회하므로
 * 반드시 verifyCustomerToken() 통과 후, 해당 customer_id 범위 안에서만 쓴다. 브라우저로 절대 내보내지 않는다.
 */
export function createAdminClient() {
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** 고객 인증 = access_token(URL) + 전화번호 뒤 4자리 (Canonical 12). */
export async function verifyCustomerToken(token: string, last4?: string) {
  const db = createAdminClient();
  const { data } = await db.from("customers").select("id, name, status, stage, phone_last4").eq("access_token", token).maybeSingle();
  if (!data) return { ok: false as const, reason: "invalid" as const };
  if (last4 !== undefined && data.phone_last4 !== last4) return { ok: false as const, reason: "last4" as const };
  return { ok: true as const, customer: data };
}
