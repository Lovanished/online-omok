import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

/**
 * 서버 전용 클라이언트. service role key를 사용해 RLS를 우회한다.
 * 절대 클라이언트(브라우저) 번들에 포함되면 안 되므로 "server.ts"는
 * app/api/** (route handler) 안에서만 import 할 것.
 */
export function getServerSupabase() {
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });
}
