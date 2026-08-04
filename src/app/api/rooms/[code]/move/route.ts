import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import {
  checkForbiddenMove,
  checkWin,
  isBoardFull,
} from "@/lib/game/gomoku";
import { isMineStillActive } from "@/lib/game/mine";
import { Board, LastMove, StoneColor } from "@/lib/game/types";

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
  // 지뢰 모드에서 방금 착수를 마쳤고 지뢰 설치 단계라면, 착수(move) API가 아니라
  // 지뢰 설치(mine) API를 호출해야 한다.
  if (room.phase !== "move") {
    return NextResponse.json(
      { error: "지금은 지뢰를 설치할 칸을 선택할 차례입니다." },
      { status: 409 }
    );
  }

  const board: Board = room.board;
  if (!board[y] || board[y][x] === undefined) {
    return NextResponse.json({ error: "보드 범위를 벗어났습니다." }, { status: 400 });
  }
  if (board[y][x] !== null) {
    return NextResponse.json({ error: "이미 돌이 놓인 자리입니다." }, { status: 400 });
  }

  const turnNumber: number = room.turn_number;
  const nextColor: StoneColor = color === "black" ? "white" : "black";

  // ---- 지뢰 모드: 이 칸에 상대가 심어둔 활성 지뢰가 있는지 확인 ----
  if (room.mode === "mine") {
    const { data: activeMines } = await supabase
      .from("mines")
      .select("*")
      .eq("room_id", room.id)
      .eq("owner_color", nextColor) // 상대(=지뢰 주인)가 설치한 지뢰
      .eq("x", x)
      .eq("y", y)
      .eq("consumed", false);

    const hitMine = (activeMines || []).find((m) =>
      isMineStillActive(m.expires_at_turn, turnNumber)
    );

    if (hitMine) {
      await supabase.from("mines").update({ consumed: true }).eq("id", hitMine.id);

      // 착수가 무효화된 경우: 지뢰 설치 단계 없이 곧바로 턴이 넘어간다.
      const lastMove: LastMove = { type: "blocked", color, x, y };
      const { data: updatedRoom } = await supabase
        .from("rooms")
        .update({
          current_turn: nextColor,
          turn_number: turnNumber + 1,
          phase: "move",
          last_move: lastMove,
        })
        .eq("id", room.id)
        .select()
        .single();

      return NextResponse.json({
        ok: true,
        invalidatedByMine: true,
        room: updatedRoom,
      });
    }
  }

  // ---- 금수 판정 (일반/지뢰 모드 공통, 흑돌만 해당) ----
  if (room.mode !== "extreme") {
    const forbiddenReason = checkForbiddenMove(board, x, y, color);
    if (forbiddenReason) {
      return NextResponse.json(
        { error: `금수입니다 (${forbiddenReason}). 다른 자리를 선택하세요.` },
        { status: 400 }
      );
    }
  }

  // ---- 착수 ----
  const newBoard: Board = board.map((row) => [...row]);
  newBoard[y][x] = color;

  const isWin = checkWin(newBoard, x, y, color);
  const isDraw = !isWin && isBoardFull(newBoard);
  const gameOver = isWin || isDraw;

  const lastMove: LastMove = { type: "stone", color, x, y };

  // 지뢰 모드 + 게임이 끝나지 않았다면: 턴을 넘기지 않고 같은 플레이어가
  // 이어서 지뢰 설치 칸을 골라야 한다 (phase='place_mine').
  const shouldEnterMinePhase = room.mode === "mine" && !gameOver;

  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update({
      board: newBoard,
      current_turn: shouldEnterMinePhase ? color : nextColor,
      turn_number: shouldEnterMinePhase ? turnNumber : turnNumber + 1,
      phase: shouldEnterMinePhase ? "place_mine" : "move",
      last_move: lastMove,
      winner: isWin ? color : isDraw ? "draw" : null,
      status: gameOver ? "finished" : "playing",
    })
    .eq("id", room.id)
    .select()
    .single();

  if (updateError || !updatedRoom) {
    return NextResponse.json({ error: updateError?.message ?? "업데이트 실패" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, room: updatedRoom });
}
