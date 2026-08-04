import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import { computeMineExpiry, isMineStillActive } from "@/lib/game/mine";
import { Board, StoneColor } from "@/lib/game/types";

export async function POST(
  req: NextRequest,
  { params }: { params: { code: string } }
) {
  const body = await req.json().catch(() => ({}));
  const { sessionToken, x, y } = body as {
    sessionToken?: string;
    x?: number;
    y?: number;
  };

  if (!sessionToken || typeof x !== "number" || typeof y !== "number") {
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
  if (room.mode !== "mine") {
    return NextResponse.json({ error: "지뢰 모드가 아닙니다." }, { status: 400 });
  }
  if (room.status !== "playing") {
    return NextResponse.json({ error: "게임이 진행 중이 아닙니다." }, { status: 409 });
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

  const color: StoneColor = player.color;
  if (room.current_turn !== color) {
    return NextResponse.json({ error: "상대의 턴입니다." }, { status: 409 });
  }
  // 착수를 먼저 마치고 이 단계에 들어와야 지뢰를 설치할 수 있다.
  if (room.phase !== "place_mine") {
    return NextResponse.json(
      { error: "먼저 착수를 해야 지뢰를 설치할 수 있습니다." },
      { status: 409 }
    );
  }

  const board: Board = room.board;
  if (!board[y] || board[y][x] === undefined) {
    return NextResponse.json({ error: "보드 범위를 벗어났습니다." }, { status: 400 });
  }
  if (board[y][x] !== null) {
    return NextResponse.json({ error: "돌이 놓인 자리에는 지뢰를 설치할 수 없습니다." }, { status: 400 });
  }

  const turnNumber: number = room.turn_number;

  // 이미 이 칸에 활성 지뢰(자신의 것이든 상대 것이든)가 있는지 확인
  const { data: existingMines } = await supabase
    .from("mines")
    .select("*")
    .eq("room_id", room.id)
    .eq("x", x)
    .eq("y", y)
    .eq("consumed", false);

  const activeExisting = (existingMines || []).find((m) =>
    isMineStillActive(m.expires_at_turn, turnNumber)
  );
  if (activeExisting) {
    return NextResponse.json({ error: "이미 지뢰가 있는 자리입니다." }, { status: 400 });
  }

  // 직전에 "자신이" 설치한 지뢰와 같은 칸인지 확인 (가장 최근 설치 기록 기준)
  const { data: lastOwnMine } = await supabase
    .from("mines")
    .select("*")
    .eq("room_id", room.id)
    .eq("owner_color", color)
    .order("placed_at_turn", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (lastOwnMine && lastOwnMine.x === x && lastOwnMine.y === y) {
    return NextResponse.json(
      { error: "직전에 지뢰를 설치했던 자리에는 다시 설치할 수 없습니다." },
      { status: 400 }
    );
  }

  const { error: insertError } = await supabase.from("mines").insert({
    room_id: room.id,
    owner_color: color,
    x,
    y,
    placed_at_turn: turnNumber,
    expires_at_turn: computeMineExpiry(turnNumber),
    consumed: false,
  });
  if (insertError) {
    return NextResponse.json({ error: insertError.message }, { status: 500 });
  }

  // 지뢰 설치까지 끝나야 비로소 턴이 상대에게 넘어간다.
  // last_move는 방금 둔 돌 위치를 그대로 유지한다 (지뢰 위치는 절대 공개하지 않음).
  const nextColor: StoneColor = color === "black" ? "white" : "black";
  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update({
      current_turn: nextColor,
      turn_number: turnNumber + 1,
      phase: "move",
    })
    .eq("id", room.id)
    .select()
    .single();

  if (updateError || !updatedRoom) {
    return NextResponse.json({ error: updateError?.message ?? "업데이트 실패" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, room: updatedRoom });
}
