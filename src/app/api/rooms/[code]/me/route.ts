import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";

export async function POST(
  req: NextRequest,
  { params }: { params: { code: string } }
) {
  const body = await req.json().catch(() => ({}));
  const { sessionToken } = body as { sessionToken?: string };
  if (!sessionToken) {
    return NextResponse.json({ error: "잘못된 요청입니다." }, { status: 400 });
  }

  const supabase = getServerSupabase();
  const code = params.code.toUpperCase();

  const { data: room, error: roomError } = await supabase
    .from("rooms")
    .select("id")
    .eq("code", code)
    .single();
  if (roomError || !room) {
    return NextResponse.json({ error: "방을 찾을 수 없습니다." }, { status: 404 });
  }

  const { data: player, error: playerError } = await supabase
    .from("players")
    .select("seat, color, nickname")
    .eq("room_id", room.id)
    .eq("session_token", sessionToken)
    .single();
  if (playerError || !player) {
    return NextResponse.json({ error: "플레이어를 확인할 수 없습니다." }, { status: 403 });
  }

  return NextResponse.json({
    color: player.color,
    seat: player.seat,
    nickname: player.nickname,
  });
}
