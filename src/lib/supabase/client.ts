"use client";

import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

// 브라우저(클라이언트)에서 쓰는 인스턴스: anon key만 사용, RLS 정책을 그대로 따른다.
// mines 테이블은 RLS 정책이 없으므로 이 클라이언트로는 절대 조회되지 않는다.
export const supabaseBrowser = createClient(url, anonKey, {
  realtime: {
    params: { eventsPerSecond: 10 },
  },
});
