#!/usr/bin/env bash
set -e
echo "지뢰 모드 턴 순서 수정 패치 적용 중..."

mkdir -p "src/lib/game"
cat > "src/lib/game/types.ts" << 'GOMOKU_FILE_EOF'
export type StoneColor = "black" | "white";
export type Cell = StoneColor | null;
export type Board = Cell[][]; // board[y][x]

export type GameMode = "normal" | "mine" | "extreme";
export type RoomStatus = "waiting" | "playing" | "finished";

export type LastMoveType = "stone" | "mine" | "blocked";

export interface LastMove {
  type: LastMoveType;
  color: StoneColor;
  // stone, blocked 타입일 때만 좌표를 공개한다.
  // mine(지뢰 설치) 타입은 위치를 절대 공개하면 안 되므로 x,y를 넣지 않는다.
  x?: number;
  y?: number;
}

export interface RoomRow {
  id: string;
  code: string;
  mode: GameMode;
  status: RoomStatus;
  board_size: number;
  host_nickname: string;
  guest_nickname: string | null;
  current_turn: StoneColor;
  // 지뢰 모드 전용 턴 진행 단계: 'move' = 착수 대기, 'place_mine' = 방금 착수한
  // 플레이어가 같은 턴에 지뢰 설치 칸을 골라야 하는 단계 (현재 턴 플레이어는 안 바뀜)
  phase: "move" | "place_mine";
  winner: StoneColor | "draw" | null;
  board: Board;
  last_move: LastMove | null;
  turn_number: number;
  created_at: string;
  updated_at: string;
}

export interface PlayerRow {
  id: string;
  room_id: string;
  color: StoneColor;
  nickname: string;
  session_token: string;
}

export interface MoveResult {
  ok: boolean;
  error?: string;
  invalidatedByMine?: boolean;
  winner?: StoneColor | "draw" | null;
  board?: Board;
  nextTurn?: StoneColor;
  turnNumber?: number;
}
GOMOKU_FILE_EOF

mkdir -p "supabase"
cat > "supabase/schema.sql" << 'GOMOKU_FILE_EOF'
-- ============================================================
-- 오목 온라인 - Supabase 스키마
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요.
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- rooms: 게임방
-- ---------------------------------------------------------------
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,               -- 6자리 초대 코드
  mode text not null default 'normal',      -- normal | mine | extreme
  status text not null default 'waiting',   -- waiting | playing | finished
  board_size int not null default 15,
  host_nickname text not null,
  guest_nickname text,
  current_turn text default 'black',        -- black | white
  phase text not null default 'move' check (phase in ('move', 'place_mine')),
                                             -- 지뢰 모드 전용: 'move'=착수 대기, 'place_mine'=방금 착수한
                                             -- 플레이어가 같은 턴에 지뢰 설치 칸을 골라야 함
  winner text,                              -- black | white | draw | null
  board jsonb not null default '[]'::jsonb, -- 15x15 돌 배치 (공개 정보만)
  last_move jsonb,                          -- {x,y,color,invalidatedByMine}
  turn_number int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- players: 방에 접속한 플레이어 (플레이어 식별용, 인증 없이 세션 토큰 기반)
-- ---------------------------------------------------------------
create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  color text not null check (color in ('black', 'white')),
  nickname text not null,
  session_token uuid not null default gen_random_uuid(), -- 클라이언트가 보관, 본인 인증용
  created_at timestamptz not null default now(),
  unique (room_id, color)
);

-- ---------------------------------------------------------------
-- mines: 지뢰 모드 전용, 절대 클라이언트에서 직접 조회 불가 (RLS로 차단)
-- 서버(API route, service role)만 읽고 씀
-- ---------------------------------------------------------------
create table if not exists mines (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  owner_color text not null check (owner_color in ('black', 'white')),
  x int not null,
  y int not null,
  placed_at_turn int not null,   -- 설치된 turn_number
  expires_at_turn int not null,  -- 이 turn_number가 되면 소멸 (상대 턴 종료 시점)
  consumed boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- chat_messages
-- ---------------------------------------------------------------
create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  nickname text not null,
  color text,
  message text not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- RLS 활성화
-- ---------------------------------------------------------------
alter table rooms enable row level security;
alter table players enable row level security;
alter table mines enable row level security;
alter table chat_messages enable row level security;

-- rooms: 누구나 읽기 가능(보드는 공개 정보만 들어있음), 쓰기는 API(service role)만
create policy "rooms_select_all" on rooms for select using (true);

-- players: 자신의 row는 못 읽어도 되지만, 방 참가자 존재 확인을 위해 읽기 허용(닉네임/색상만 노출)
create policy "players_select_all" on players for select using (true);

-- chat_messages: 누구나 읽기/쓰기 가능 (방 코드 기반 공개 채팅)
create policy "chat_select_all" on chat_messages for select using (true);
create policy "chat_insert_all" on chat_messages for insert with check (true);

-- mines: 어떤 정책도 만들지 않음 -> 클라이언트(anon key)는 절대 조회 불가.
-- service role key(API route)는 RLS를 우회하므로 서버에서만 접근 가능.

-- ---------------------------------------------------------------
-- Realtime 활성화 (Supabase 대시보드 > Database > Replication 에서도 설정 가능)
-- ---------------------------------------------------------------
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table chat_messages;
alter publication supabase_realtime add table players;

-- rooms.updated_at 자동 갱신 트리거
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_rooms_updated_at on rooms;
create trigger trg_rooms_updated_at
before update on rooms
for each row execute function set_updated_at();
GOMOKU_FILE_EOF

mkdir -p "supabase/migrations"
cat > "supabase/migrations/002_add_phase.sql" << 'GOMOKU_FILE_EOF'
-- 이미 supabase/schema.sql을 한 번 실행해서 rooms 테이블이 이미 있다면,
-- Supabase SQL Editor에서 이 파일만 추가로 실행하세요.
-- (schema.sql을 처음부터 새로 실행하는 경우에는 필요 없습니다 - 이미 포함되어 있음)

alter table rooms
  add column if not exists phase text not null default 'move';

alter table rooms
  drop constraint if exists rooms_phase_check;

alter table rooms
  add constraint rooms_phase_check check (phase in ('move', 'place_mine'));
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/move"
cat > "src/app/api/rooms/[code]/move/route.ts" << 'GOMOKU_FILE_EOF'
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
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/mine"
cat > "src/app/api/rooms/[code]/mine/route.ts" << 'GOMOKU_FILE_EOF'
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
GOMOKU_FILE_EOF

mkdir -p "src/app/room/[code]"
cat > "src/app/room/[code]/RoomClient.tsx" << 'GOMOKU_FILE_EOF'
"use client";

import { useState } from "react";
import { useRoomRealtime } from "@/hooks/useRoomRealtime";
import { RoomRow, StoneColor } from "@/lib/game/types";
import Board from "@/components/Board";
import Chat from "@/components/Chat";
import EmojiBar from "@/components/EmojiBar";

interface Session {
  sessionToken: string;
  color: StoneColor;
  nickname: string;
}

const MODE_LABEL: Record<string, string> = {
  normal: "일반 모드",
  mine: "지뢰 모드",
  extreme: "익스트림 모드 (준비 중)",
};

export default function RoomClient({
  initialRoom,
  session,
}: {
  initialRoom: RoomRow;
  session: Session;
}) {
  const { room, messages, emojiEvents, sendChat, sendEmoji } = useRoomRealtime(initialRoom);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const isMyTurn = room.current_turn === session.color && room.status === "playing";
  const waitingForOpponent = room.status === "waiting";
  // 지뢰 모드에서 방금 착수를 마치고, 같은 턴에 지뢰 설치 칸을 골라야 하는 단계인지
  const mustPlaceMine = room.mode === "mine" && room.phase === "place_mine" && isMyTurn;

  async function handleCellClick(x: number, y: number) {
    if (!isMyTurn || busy) return;
    setBusy(true);
    setActionError(null);
    try {
      const endpoint = mustPlaceMine
        ? `/api/rooms/${room.code}/mine`
        : `/api/rooms/${room.code}/move`;
      const res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionToken: session.sessionToken, x, y }),
      });
      const data = await res.json();
      if (!res.ok) {
        setActionError(data.error);
        return;
      }
    } finally {
      setBusy(false);
    }
  }

  const opponentNickname =
    session.color === "black" ? room.guest_nickname : room.host_nickname;
  const myNickname = session.color === "black" ? room.host_nickname : room.guest_nickname;
  const opponentIsPlacingMine =
    room.mode === "mine" && room.phase === "place_mine" && !isMyTurn && room.status === "playing";

  return (
    <main className="min-h-screen p-4 md:p-8 flex flex-col items-center gap-6">
      <div className="w-full max-w-3xl flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold">방 코드: {room.code}</h1>
          <p className="text-sm text-gray-400">{MODE_LABEL[room.mode]}</p>
        </div>
        <div className="text-right text-sm">
          <p>
            나: <span className="font-semibold">{myNickname}</span> (
            {session.color === "black" ? "흑" : "백"})
          </p>
          <p className="text-gray-400">
            상대: {opponentNickname ?? "대기 중..."}
          </p>
        </div>
      </div>

      {waitingForOpponent && (
        <p className="text-amber-300">
          상대가 참가하길 기다리는 중입니다. 방 코드를 공유해보세요: <b>{room.code}</b>
        </p>
      )}

      {room.status === "finished" && (
        <p className="text-lg font-bold text-amber-300">
          {room.winner === "draw"
            ? "무승부입니다."
            : `${room.winner === "black" ? "흑" : "백"} 승리!`}
        </p>
      )}

      {room.status === "playing" && (
        <p
          className={
            mustPlaceMine
              ? "text-red-400 font-semibold"
              : isMyTurn
              ? "text-emerald-400 font-semibold"
              : "text-gray-400"
          }
        >
          {mustPlaceMine
            ? "💣 이어서 지뢰를 설치할 칸을 선택하세요 (빈 칸 아무 곳이나)."
            : isMyTurn
            ? "내 차례입니다. 돌을 놓을 칸을 선택하세요."
            : opponentIsPlacingMine
            ? `${opponentNickname ?? "상대"}가 지뢰를 설치할 칸을 고르는 중입니다...`
            : `${opponentNickname ?? "상대"}의 차례입니다.`}
        </p>
      )}

      <div className="overflow-auto max-w-full">
        <Board
          board={room.board}
          lastMove={room.last_move}
          disabled={!isMyTurn || busy}
          onCellClick={handleCellClick}
          placingMine={mustPlaceMine}
        />
      </div>

      {actionError && <p className="text-red-400 text-sm">{actionError}</p>}

      <div className="w-full max-w-md space-y-3">
        <EmojiBar events={emojiEvents} onSend={(emoji) => sendEmoji(session.nickname, emoji)} />
        <Chat
          messages={messages}
          onSend={(msg) => sendChat(session.nickname, session.color, msg)}
        />
      </div>
    </main>
  );
}
GOMOKU_FILE_EOF

echo "패치 완료. Supabase SQL Editor에서 supabase/migrations/002_add_phase.sql 도 실행해주세요."