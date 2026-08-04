import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";

export async function POST(
  req: NextRequest,
  { params }: { params: { code: string } }
) {
  const body = await req.json().catch(() => ({}));
  const nickname = (body.nickname || "").toString().trim().slice(0, 20);
  if (!nickname) {
    return NextResponse.json({ error: "닉네임을 입력해주세요." }, { status: 400 });
  }

  const supabase = getServerSupabase();
  const code = params.code.toUpperCase();

  const { data: room, error } = await supabase
    .from("rooms")
    .select("*")
    .eq("code", code)
    .single();

  if (error || !room) {
    return NextResponse.json({ error: "방을 찾을 수 없습니다." }, { status: 404 });
  }

  if (room.guest_nickname) {
    // 이미 두 명이 있다면 관전자로는 이번 MVP에서 지원하지 않음
    return NextResponse.json({ error: "이미 인원이 가득 찬 방입니다." }, { status: 409 });
  }

  const { data: player, error: playerError } = await supabase
    .from("players")
    .insert({ room_id: room.id, color: "white", nickname })
    .select()
    .single();

  if (playerError || !player) {
    return NextResponse.json({ error: playerError?.message ?? "참가 실패" }, { status: 500 });
  }

  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update({ guest_nickname: nickname, status: "playing" })
    .eq("id", room.id)
    .select()
    .single();

  if (updateError || !updatedRoom) {
    return NextResponse.json({ error: updateError?.message ?? "방 업데이트 실패" }, { status: 500 });
  }

  return NextResponse.json({
    room: updatedRoom,
    sessionToken: player.session_token,
    color: "white",
  });
}
