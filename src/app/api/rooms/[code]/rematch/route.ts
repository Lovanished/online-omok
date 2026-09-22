import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import { createEmptyBoard } from "@/lib/game/gomoku";
import { Seat, StoneColor } from "@/lib/game/types";

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
    .select("*")
    .eq("code", code)
    .single();
  if (roomError || !room) {
    return NextResponse.json({ error: "방을 찾을 수 없습니다." }, { status: 404 });
  }
  if (room.status !== "finished") {
    return NextResponse.json({ error: "게임이 아직 끝나지 않았습니다." }, { status: 409 });
  }

  const { data: player, error: playerError } = await supabase
    .from("players")
    .select("*")
    .eq("room_id", room.id)
    .eq("session_token", sessionToken)
    .single();
  if (playerError || !player) {
    return NextResponse.json({ error: "플레이어를 확인할 수 없습니다." }, { status: 403 });
  }

  const seat: Seat = player.seat;
  const flagColumn = seat === "host" ? "rematch_host_requested" : "rematch_guest_requested";

  const { data: flaggedRoom, error: flagError } = await supabase
    .from("rooms")
    .update({ [flagColumn]: true })
    .eq("id", room.id)
    .select()
    .single();

  if (flagError || !flaggedRoom) {
    return NextResponse.json({ error: flagError?.message ?? "업데이트 실패" }, { status: 500 });
  }

  const bothReady = flaggedRoom.rematch_host_requested && flaggedRoom.rematch_guest_requested;

  if (!bothReady) {
    return NextResponse.json({ ok: true, room: flaggedRoom, myColor: player.color });
  }

  // ---- 양쪽 모두 재대국에 동의함: 새 판 시작, 흑백 랜덤 재배정 ----
  const newHostColor: StoneColor = Math.random() < 0.5 ? "black" : "white";
  const newGuestColor: StoneColor = newHostColor === "black" ? "white" : "black";

  await supabase.from("mines").delete().eq("room_id", room.id);

  await supabase
    .from("players")
    .update({ color: newHostColor })
    .eq("room_id", room.id)
    .eq("seat", "host");
  await supabase
    .from("players")
    .update({ color: newGuestColor })
    .eq("room_id", room.id)
    .eq("seat", "guest");

  const { data: resetRoom, error: resetError } = await supabase
    .from("rooms")
    .update({
      status: "playing",
      board: createEmptyBoard(room.board_size ?? 15),
      current_turn: "black",
      phase: "move",
      winner: null,
      last_move: null,
      turn_number: 0,
      draw_offered_by: null,
      rematch_host_requested: false,
      rematch_guest_requested: false,
    })
    .eq("id", room.id)
    .select()
    .single();

  if (resetError || !resetRoom) {
    return NextResponse.json({ error: resetError?.message ?? "재대국 시작 실패" }, { status: 500 });
  }

  const myNewColor = seat === "host" ? newHostColor : newGuestColor;

  return NextResponse.json({ ok: true, room: resetRoom, myColor: myNewColor });
}
