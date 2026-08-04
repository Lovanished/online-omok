import { NextRequest, NextResponse } from "next/server";
import { customAlphabet } from "nanoid";
import { getServerSupabase } from "@/lib/supabase/server";
import { createEmptyBoard } from "@/lib/game/gomoku";
import { GameMode } from "@/lib/game/types";

const genCode = customAlphabet("ABCDEFGHJKLMNPQRSTUVWXYZ23456789", 6);

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const nickname = (body.nickname || "").toString().trim().slice(0, 20);
  const mode: GameMode = ["normal", "mine", "extreme"].includes(body.mode)
    ? body.mode
    : "normal";

  if (!nickname) {
    return NextResponse.json({ error: "닉네임을 입력해주세요." }, { status: 400 });
  }

  const supabase = getServerSupabase();
  const code = genCode();

  const { data: room, error } = await supabase
    .from("rooms")
    .insert({
      code,
      mode,
      status: "waiting",
      host_nickname: nickname,
      board: createEmptyBoard(),
      current_turn: "black",
    })
    .select()
    .single();

  if (error || !room) {
    return NextResponse.json({ error: error?.message ?? "방 생성 실패" }, { status: 500 });
  }

  const { data: player, error: playerError } = await supabase
    .from("players")
    .insert({ room_id: room.id, color: "black", nickname })
    .select()
    .single();

  if (playerError || !player) {
    return NextResponse.json({ error: playerError?.message ?? "플레이어 생성 실패" }, { status: 500 });
  }

  return NextResponse.json({
    room,
    sessionToken: player.session_token,
    color: "black",
  });
}
