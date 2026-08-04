#!/usr/bin/env bash
set -e
echo "오목 온라인 프로젝트 파일 생성 시작..."

cat > ".env.example" << 'GOMOKU_FILE_EOF'
# Supabase 프로젝트 설정 (Supabase 대시보드 > Project Settings > API)
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY

# 서버 전용 (절대 클라이언트에 노출 금지, Vercel 환경변수에만 등록)
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
GOMOKU_FILE_EOF

cat > ".gitignore" << 'GOMOKU_FILE_EOF'
node_modules
.next
out
.env
.env.local
.vercel
*.log
.DS_Store
GOMOKU_FILE_EOF

cat > "README.md" << 'GOMOKU_FILE_EOF'
# 오목 온라인 (Gomoku Online)

친구와 실시간으로 즐기는 온라인 오목. Next.js + Supabase + Vercel 기반.

## 기능
- 방 생성 / 초대 코드로 참가
- 실시간 채팅, 실시간 이모지 반응
- 게임 모드
  - **일반 모드**: 표준 오목 규칙 + 흑돌 금수(장목, 33, 44)
  - **지뢰 모드**: 일반 모드 + 상대에게 보이지 않는 지뢰
  - **익스트림 모드**: 아직 규칙 미정 (UI/구조만 준비된 스텁, 아이디어가 정해지면
    `src/lib/game/` 에 새 모듈을 추가하고 `move` API의 분기만 확장하면 됩니다)

## 지뢰 모드 규칙 구현
- 자신의 턴에 "돌 두기" 또는 "지뢰 설치" 중 하나를 선택 (지뢰 설치도 턴을 소모합니다)
- 지뢰는 `mines` 테이블에만 저장되고, 이 테이블은 RLS 정책이 전혀 없어
  브라우저(anon key)로는 절대 조회할 수 없습니다. 오직 서버 API 라우트
  (service role key)만 접근 가능 → 상대에게 위치가 노출되지 않습니다.
- 설치 턴을 T라 하면, 상대 턴(T+1)까지 유효하고 그 다음(T+2)에 자동 소멸합니다.
- 상대가 지뢰 칸에 착수하면 착수가 무효 처리되고 턴만 다시 넘어갑니다
  (이때는 위치가 공개됩니다 - 규칙상 당연히 드러나는 정보이므로).
- 직전에 자신이 설치한 지뢰와 같은 칸에는 곧바로 재설치할 수 없습니다.

> 참고: 렌주 금수(33/44) 판정 로직(`src/lib/game/gomoku.ts`)은 실전에서 흔히 쓰이는
> 패턴 매칭 방식의 간이 구현입니다. 대부분의 상황에서 정확하지만, 아주 드문 복합
> 패턴 엣지 케이스까지 100% 커버하진 않을 수 있어 실제 사용 전 테스트를 권장합니다.

## 로컬 개발 준비

### 1. 저장소 클론 & 패키지 설치
```bash
npm install
```

### 2. Supabase 프로젝트 생성
1. https://supabase.com 에서 새 프로젝트 생성
2. 프로젝트의 **SQL Editor** 에서 `supabase/schema.sql` 내용을 그대로 실행
3. **Project Settings > API** 에서 다음 값을 확인:
   - Project URL
   - `anon` `public` key
   - `service_role` key (⚠️ 절대 클라이언트에 노출 금지)
4. **Database > Replication** 에서 `rooms`, `chat_messages`, `players` 테이블의
   Realtime이 켜져 있는지 확인 (schema.sql이 이미 publication에 추가함)

### 3. 환경변수 설정
```bash
cp .env.example .env.local
```
`.env.local` 을 열어 위에서 확인한 값을 채워넣습니다.

### 4. 개발 서버 실행
```bash
npm run dev
```
http://localhost:3000 접속

## GitHub 저장소에 올리기
```bash
git init
git add .
git commit -m "chore: initial gomoku online scaffold"
git branch -M main
git remote add origin https://github.com/<your-username>/<repo-name>.git
git push -u origin main
```

## Vercel 배포
1. https://vercel.com 에서 "Add New Project" → 위 GitHub 저장소 선택
2. **Environment Variables** 에 `.env.local`과 동일한 3개 값 등록
   (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`)
3. Deploy 클릭 → 완료 후 발급된 URL을 친구와 공유하면 바로 플레이 가능

## 프로젝트 구조
```
src/
  app/
    page.tsx                 방 생성/참가 홈 화면
    room/[code]/page.tsx     방 입장 처리
    room/[code]/RoomClient.tsx  실제 게임 화면(보드/채팅/이모지)
    api/rooms/route.ts       방 생성 API
    api/rooms/[code]/join    방 참가 API
    api/rooms/[code]/move    착수 처리(금수/지뢰 판정 포함)
    api/rooms/[code]/mine    지뢰 설치 API
  lib/game/
    gomoku.ts                보드 로직, 승리/금수 판정
    mine.ts                  지뢰 유효기간 계산 등 순수 로직
    types.ts                 공용 타입
  lib/supabase/
    client.ts                브라우저용(anon key)
    server.ts                서버 전용(service role key, API route에서만 import)
  hooks/useRoomRealtime.ts   보드/채팅/이모지 실시간 구독
  components/                Board, Chat, EmojiBar
supabase/schema.sql          테이블, RLS 정책, Realtime 설정
```

## 알려진 제한사항 (다음 작업 후보)
- 인증이 없는 가벼운 `session_token` 기반 식별 방식이라, 같은 브라우저에서
  로컬스토리지를 지우면 재접속 시 새 플레이어로 인식됩니다. 필요하면 Supabase
  Auth(익명 로그인)로 교체하는 것을 권장합니다.
- 관전자(spectator) 기능 없음 (2인 전용)
- 재접속 시 타이머/오프라인 처리 없음
- 익스트림 모드는 스텁 상태
GOMOKU_FILE_EOF

cat > "next.config.mjs" << 'GOMOKU_FILE_EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
};

export default nextConfig;
GOMOKU_FILE_EOF

cat > "package.json" << 'GOMOKU_FILE_EOF'
{
  "name": "gomoku-online",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.45.4",
    "next": "14.2.5",
    "nanoid": "^5.0.7",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/node": "^20.14.9",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "tailwindcss": "^3.4.4",
    "typescript": "^5.5.3"
  }
}
GOMOKU_FILE_EOF

cat > "postcss.config.js" << 'GOMOKU_FILE_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/join"
cat > "src/app/api/rooms/[code]/join/route.ts" << 'GOMOKU_FILE_EOF'
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
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/mine"
cat > "src/app/api/rooms/[code]/mine/route.ts" << 'GOMOKU_FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import { computeMineExpiry, isMineStillActive } from "@/lib/game/mine";
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

  const nextColor: StoneColor = color === "black" ? "white" : "black";
  // 지뢰 설치는 "행동"만 공개하고 좌표는 절대 공개하지 않는다.
  const lastMove: LastMove = { type: "mine", color };

  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update({
      current_turn: nextColor,
      turn_number: turnNumber + 1,
      last_move: lastMove,
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

      const lastMove: LastMove = { type: "blocked", color, x, y };
      const { data: updatedRoom } = await supabase
        .from("rooms")
        .update({
          current_turn: nextColor,
          turn_number: turnNumber + 1,
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

  const lastMove: LastMove = { type: "stone", color, x, y };

  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update({
      board: newBoard,
      current_turn: nextColor,
      turn_number: turnNumber + 1,
      last_move: lastMove,
      winner: isWin ? color : isDraw ? "draw" : null,
      status: isWin || isDraw ? "finished" : "playing",
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

mkdir -p "src/app/api/rooms"
cat > "src/app/api/rooms/route.ts" << 'GOMOKU_FILE_EOF'
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
GOMOKU_FILE_EOF

mkdir -p "src/app"
cat > "src/app/globals.css" << 'GOMOKU_FILE_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

html,
body {
  height: 100%;
}

body {
  background: #1f2937;
  color: #f3f4f6;
}
GOMOKU_FILE_EOF

mkdir -p "src/app"
cat > "src/app/layout.tsx" << 'GOMOKU_FILE_EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "오목 온라인",
  description: "친구와 실시간으로 즐기는 온라인 오목",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
GOMOKU_FILE_EOF

mkdir -p "src/app"
cat > "src/app/page.tsx" << 'GOMOKU_FILE_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { GameMode } from "@/lib/game/types";

const MODE_INFO: { value: GameMode; label: string; desc: string }[] = [
  { value: "normal", label: "일반 모드", desc: "표준 오목 규칙 + 금수(장목/33/44)" },
  { value: "mine", label: "지뢰 모드", desc: "일반 모드 + 숨겨진 지뢰 요소" },
  { value: "extreme", label: "익스트림 모드", desc: "추후 업데이트 예정" },
];

export default function HomePage() {
  const router = useRouter();
  const [nickname, setNickname] = useState("");
  const [mode, setMode] = useState<GameMode>("normal");
  const [joinCode, setJoinCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function createRoom() {
    if (!nickname.trim()) {
      setError("닉네임을 입력해주세요.");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/rooms", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nickname, mode }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      localStorage.setItem(
        `gomoku:${data.room.code}`,
        JSON.stringify({ sessionToken: data.sessionToken, color: data.color, nickname })
      );
      router.push(`/room/${data.room.code}`);
    } catch (e: any) {
      setError(e.message || "방 생성에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  }

  async function joinRoom() {
    if (!nickname.trim() || !joinCode.trim()) {
      setError("닉네임과 초대 코드를 입력해주세요.");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const code = joinCode.trim().toUpperCase();
      const res = await fetch(`/api/rooms/${code}/join`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nickname }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      localStorage.setItem(
        `gomoku:${code}`,
        JSON.stringify({ sessionToken: data.sessionToken, color: data.color, nickname })
      );
      router.push(`/room/${code}`);
    } catch (e: any) {
      setError(e.message || "참가에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-6">
      <div className="w-full max-w-md bg-gray-800 rounded-2xl shadow-xl p-8 space-y-6">
        <h1 className="text-3xl font-bold text-center">🎯 오목 온라인</h1>

        <div className="space-y-2">
          <label className="text-sm text-gray-300">닉네임</label>
          <input
            className="w-full rounded-lg bg-gray-700 px-3 py-2 outline-none focus:ring-2 focus:ring-amber-400"
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            placeholder="닉네임을 입력하세요"
            maxLength={20}
          />
        </div>

        <div className="space-y-2">
          <label className="text-sm text-gray-300">게임 모드 (방 생성 시)</label>
          <div className="grid grid-cols-1 gap-2">
            {MODE_INFO.map((m) => (
              <button
                key={m.value}
                onClick={() => setMode(m.value)}
                className={`text-left rounded-lg border px-3 py-2 transition ${
                  mode === m.value
                    ? "border-amber-400 bg-amber-400/10"
                    : "border-gray-600 hover:border-gray-500"
                }`}
              >
                <div className="font-semibold">{m.label}</div>
                <div className="text-xs text-gray-400">{m.desc}</div>
              </button>
            ))}
          </div>
        </div>

        <button
          onClick={createRoom}
          disabled={loading}
          className="w-full rounded-lg bg-amber-500 hover:bg-amber-400 disabled:opacity-50 py-2 font-semibold text-gray-900"
        >
          방 만들기
        </button>

        <div className="flex items-center gap-2 text-gray-500 text-sm">
          <div className="h-px flex-1 bg-gray-700" />
          또는 초대 코드로 참가
          <div className="h-px flex-1 bg-gray-700" />
        </div>

        <div className="flex gap-2">
          <input
            className="flex-1 rounded-lg bg-gray-700 px-3 py-2 outline-none focus:ring-2 focus:ring-amber-400 uppercase"
            value={joinCode}
            onChange={(e) => setJoinCode(e.target.value)}
            placeholder="초대 코드 (예: AB12CD)"
            maxLength={6}
          />
          <button
            onClick={joinRoom}
            disabled={loading}
            className="rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-50 px-4 font-semibold"
          >
            참가
          </button>
        </div>

        {error && <p className="text-red-400 text-sm text-center">{error}</p>}
      </div>
    </main>
  );
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
  const [placingMine, setPlacingMine] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const isMyTurn = room.current_turn === session.color && room.status === "playing";
  const waitingForOpponent = room.status === "waiting";

  async function handleCellClick(x: number, y: number) {
    if (!isMyTurn || busy) return;
    setBusy(true);
    setActionError(null);
    try {
      const endpoint = placingMine
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
      setPlacingMine(false);
    } finally {
      setBusy(false);
    }
  }

  const opponentColor: StoneColor = session.color === "black" ? "white" : "black";
  const opponentNickname =
    session.color === "black" ? room.guest_nickname : room.host_nickname;
  const myNickname = session.color === "black" ? room.host_nickname : room.guest_nickname;

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
        <p className={isMyTurn ? "text-emerald-400 font-semibold" : "text-gray-400"}>
          {isMyTurn ? "내 차례입니다." : `${opponentNickname ?? "상대"}의 차례입니다.`}
        </p>
      )}

      <div className="overflow-auto max-w-full">
        <Board
          board={room.board}
          lastMove={room.last_move}
          disabled={!isMyTurn || busy}
          onCellClick={handleCellClick}
          placingMine={placingMine}
        />
      </div>

      {actionError && <p className="text-red-400 text-sm">{actionError}</p>}

      {room.mode === "mine" && room.status === "playing" && (
        <button
          onClick={() => setPlacingMine((v) => !v)}
          disabled={!isMyTurn || busy}
          className={`px-4 py-2 rounded-lg font-semibold disabled:opacity-40 ${
            placingMine ? "bg-red-500 text-white" : "bg-gray-700 hover:bg-gray-600"
          }`}
        >
          {placingMine ? "지뢰 설치 취소" : "💣 지뢰 설치 모드"}
        </button>
      )}

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

mkdir -p "src/app/room/[code]"
cat > "src/app/room/[code]/page.tsx" << 'GOMOKU_FILE_EOF'
"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase/client";
import { RoomRow } from "@/lib/game/types";
import RoomClient from "./RoomClient";

interface Session {
  sessionToken: string;
  color: "black" | "white";
  nickname: string;
}

export default function RoomPage() {
  const params = useParams();
  const code = (params.code as string).toUpperCase();

  const [room, setRoom] = useState<RoomRow | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [nickname, setNickname] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  async function loadRoom() {
    const { data } = await supabaseBrowser
      .from("rooms")
      .select("*")
      .eq("code", code)
      .single();
    setRoom((data as RoomRow) ?? null);
  }

  useEffect(() => {
    const raw = localStorage.getItem(`gomoku:${code}`);
    if (raw) {
      setSession(JSON.parse(raw));
    }
    loadRoom().finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code]);

  async function joinAsGuest() {
    if (!nickname.trim()) {
      setError("닉네임을 입력해주세요.");
      return;
    }
    const res = await fetch(`/api/rooms/${code}/join`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nickname }),
    });
    const data = await res.json();
    if (!res.ok) {
      setError(data.error);
      return;
    }
    const s: Session = { sessionToken: data.sessionToken, color: data.color, nickname };
    localStorage.setItem(`gomoku:${code}`, JSON.stringify(s));
    setSession(s);
    setRoom(data.room);
  }

  if (loading) {
    return <main className="min-h-screen flex items-center justify-center text-gray-400">불러오는 중...</main>;
  }

  if (!room) {
    return (
      <main className="min-h-screen flex items-center justify-center text-gray-400">
        존재하지 않는 방입니다.
      </main>
    );
  }

  if (!session) {
    return (
      <main className="min-h-screen flex items-center justify-center p-6">
        <div className="w-full max-w-sm bg-gray-800 rounded-2xl p-8 space-y-4">
          <h2 className="text-xl font-bold text-center">
            {room.host_nickname}님의 방에 참가하기
          </h2>
          <input
            className="w-full rounded-lg bg-gray-700 px-3 py-2 outline-none"
            placeholder="닉네임"
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            maxLength={20}
          />
          <button
            onClick={joinAsGuest}
            className="w-full rounded-lg bg-amber-500 hover:bg-amber-400 py-2 font-semibold text-gray-900"
          >
            참가하기
          </button>
          {error && <p className="text-red-400 text-sm text-center">{error}</p>}
        </div>
      </main>
    );
  }

  return <RoomClient initialRoom={room} session={session} />;
}
GOMOKU_FILE_EOF

mkdir -p "src/components"
cat > "src/components/Board.tsx" << 'GOMOKU_FILE_EOF'
"use client";

import { Board as BoardType, LastMove } from "@/lib/game/types";

interface Props {
  board: BoardType;
  lastMove: LastMove | null;
  disabled: boolean;
  onCellClick: (x: number, y: number) => void;
  placingMine?: boolean;
}

export default function Board({ board, lastMove, disabled, onCellClick, placingMine }: Props) {
  const size = board.length;

  return (
    <div
      className="inline-grid bg-board rounded-lg shadow-lg select-none touch-none"
      style={{
        gridTemplateColumns: `repeat(${size}, minmax(20px, 32px))`,
        gridTemplateRows: `repeat(${size}, minmax(20px, 32px))`,
        padding: "12px",
      }}
    >
      {board.map((row, y) =>
        row.map((cell, x) => {
          const isLast =
            lastMove &&
            lastMove.type !== "mine" &&
            lastMove.x === x &&
            lastMove.y === y;
          return (
            <button
              key={`${x}-${y}`}
              disabled={disabled || cell !== null}
              onClick={() => onCellClick(x, y)}
              className={`relative border border-black/30 flex items-center justify-center ${
                placingMine ? "hover:bg-red-400/40" : "hover:bg-black/10"
              } disabled:cursor-default`}
              aria-label={`${x},${y}`}
            >
              {cell && (
                <span
                  className={`block rounded-full ${
                    cell === "black" ? "bg-gray-900" : "bg-white border border-gray-400"
                  }`}
                  style={{ width: "78%", height: "78%" }}
                />
              )}
              {isLast && (
                <span className="absolute inset-0 border-2 border-amber-500 rounded-sm pointer-events-none" />
              )}
            </button>
          );
        })
      )}
    </div>
  );
}
GOMOKU_FILE_EOF

mkdir -p "src/components"
cat > "src/components/Chat.tsx" << 'GOMOKU_FILE_EOF'
"use client";

import { useEffect, useRef, useState } from "react";
import { ChatMessage } from "@/hooks/useRoomRealtime";

interface Props {
  messages: ChatMessage[];
  onSend: (message: string) => void;
}

export default function Chat({ messages, onSend }: Props) {
  const [text, setText] = useState("");
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight });
  }, [messages.length]);

  function submit() {
    if (!text.trim()) return;
    onSend(text);
    setText("");
  }

  return (
    <div className="flex flex-col h-64 bg-gray-800 rounded-lg overflow-hidden">
      <div ref={listRef} className="flex-1 overflow-y-auto p-3 space-y-1 text-sm">
        {messages.map((m) => (
          <div key={m.id}>
            <span
              className={`font-semibold mr-1 ${
                m.color === "black"
                  ? "text-gray-300"
                  : m.color === "white"
                  ? "text-amber-200"
                  : "text-gray-400"
              }`}
            >
              {m.nickname}:
            </span>
            <span className="text-gray-100">{m.message}</span>
          </div>
        ))}
      </div>
      <div className="flex border-t border-gray-700">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submit()}
          placeholder="메시지 입력..."
          maxLength={300}
          className="flex-1 bg-gray-900 px-3 py-2 outline-none text-sm"
        />
        <button
          onClick={submit}
          className="px-4 bg-amber-500 hover:bg-amber-400 text-gray-900 font-semibold text-sm"
        >
          전송
        </button>
      </div>
    </div>
  );
}
GOMOKU_FILE_EOF

mkdir -p "src/components"
cat > "src/components/EmojiBar.tsx" << 'GOMOKU_FILE_EOF'
"use client";

import { EmojiEvent } from "@/hooks/useRoomRealtime";

const EMOJIS = ["👍", "😂", "😮", "😡", "🔥", "🤔"];

interface Props {
  events: EmojiEvent[];
  onSend: (emoji: string) => void;
}

export default function EmojiBar({ events, onSend }: Props) {
  return (
    <div className="relative">
      <div className="flex gap-2">
        {EMOJIS.map((e) => (
          <button
            key={e}
            onClick={() => onSend(e)}
            className="text-2xl hover:scale-125 transition-transform"
          >
            {e}
          </button>
        ))}
      </div>
      <div className="absolute bottom-full left-0 mb-2 flex flex-col gap-1 pointer-events-none">
        {events.slice(-5).map((e) => (
          <div
            key={e.id}
            className="animate-bounce bg-gray-900/80 rounded-full px-2 py-1 text-sm w-fit"
          >
            {e.emoji} <span className="text-gray-400 text-xs">{e.nickname}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
GOMOKU_FILE_EOF

mkdir -p "src/hooks"
cat > "src/hooks/useRoomRealtime.ts" << 'GOMOKU_FILE_EOF'
"use client";

import { useEffect, useRef, useState } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";
import { RoomRow } from "@/lib/game/types";

export interface ChatMessage {
  id: string;
  nickname: string;
  color: string | null;
  message: string;
  created_at: string;
}

export interface EmojiEvent {
  emoji: string;
  nickname: string;
  id: number;
}

export function useRoomRealtime(initialRoom: RoomRow) {
  const [room, setRoom] = useState<RoomRow>(initialRoom);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [emojiEvents, setEmojiEvents] = useState<EmojiEvent[]>([]);
  const emojiIdRef = useRef(0);
  const channelRef = useRef<ReturnType<typeof supabaseBrowser.channel> | null>(null);

  useEffect(() => {
    // 초기 채팅 기록 로드
    supabaseBrowser
      .from("chat_messages")
      .select("*")
      .eq("room_id", initialRoom.id)
      .order("created_at", { ascending: true })
      .limit(200)
      .then(({ data }) => {
        if (data) setMessages(data as ChatMessage[]);
      });

    const channel = supabaseBrowser
      .channel(`room-${initialRoom.id}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "rooms",
          filter: `id=eq.${initialRoom.id}`,
        },
        (payload) => {
          setRoom(payload.new as RoomRow);
        }
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "chat_messages",
          filter: `room_id=eq.${initialRoom.id}`,
        },
        (payload) => {
          setMessages((prev) => [...prev, payload.new as ChatMessage]);
        }
      )
      .on("broadcast", { event: "emoji" }, (payload) => {
        const p = payload.payload as { emoji: string; nickname: string };
        emojiIdRef.current += 1;
        const evt = { ...p, id: emojiIdRef.current };
        setEmojiEvents((prev) => [...prev.slice(-20), evt]);
      })
      .subscribe();

    channelRef.current = channel;

    return () => {
      supabaseBrowser.removeChannel(channel);
      channelRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialRoom.id]);

  async function sendChat(nickname: string, color: string, message: string) {
    if (!message.trim()) return;
    await supabaseBrowser.from("chat_messages").insert({
      room_id: initialRoom.id,
      nickname,
      color,
      message: message.slice(0, 300),
    });
  }

  async function sendEmoji(nickname: string, emoji: string) {
    if (!channelRef.current) return;
    await channelRef.current.send({
      type: "broadcast",
      event: "emoji",
      payload: { emoji, nickname },
    });
  }

  return { room, messages, emojiEvents, sendChat, sendEmoji };
}
GOMOKU_FILE_EOF

mkdir -p "src/lib/game"
cat > "src/lib/game/gomoku.ts" << 'GOMOKU_FILE_EOF'
import { Board, Cell, StoneColor } from "./types";

export const BOARD_SIZE = 15;

export function createEmptyBoard(size = BOARD_SIZE): Board {
  return Array.from({ length: size }, () => Array<Cell>(size).fill(null));
}

export function inBounds(board: Board, x: number, y: number): boolean {
  return y >= 0 && y < board.length && x >= 0 && x < board[0].length;
}

export function cloneBoard(board: Board): Board {
  return board.map((row) => [...row]);
}

const DIRECTIONS: [number, number][] = [
  [1, 0], // 가로
  [0, 1], // 세로
  [1, 1], // 대각선 \
  [1, -1], // 대각선 /
];

/**
 * (x,y) 기준 한 방향으로 뻗은 라인을 문자열로 인코딩한다.
 * 'S' = 기준 돌 색과 동일, 'B' = 상대 돌 또는 보드 밖(막힘), '.' = 빈칸
 * radius 만큼 좌우로 뻗어서 문자열을 만들고, 중앙 인덱스(=radius)가 (x,y) 위치.
 */
function encodeLine(
  board: Board,
  x: number,
  y: number,
  dx: number,
  dy: number,
  color: StoneColor,
  radius: number
): string {
  let out = "";
  for (let i = -radius; i <= radius; i++) {
    const cx = x + dx * i;
    const cy = y + dy * i;
    if (i === 0) {
      out += "S"; // 가정: 이 자리에 방금 돌을 놓았다고 가정
      continue;
    }
    if (!inBounds(board, cx, cy)) {
      out += "B";
      continue;
    }
    const cell = board[cy][cx];
    if (cell === null) out += ".";
    else if (cell === color) out += "S";
    else out += "B";
  }
  return out;
}

/** 정확히 5개 연속(장목 아님)인지 확인 */
export function checkExactFive(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  for (const [dx, dy] of DIRECTIONS) {
    const line = encodeLine(board, x, y, dx, dy, color, 5);
    // 5연속 S가 있고, 그 앞뒤가 S가 아니면(=6개 이상 아니면) 정확한 5
    const re = /S{5}/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(line))) {
      const start = m.index;
      const end = start + 5;
      const before = line[start - 1];
      const after = line[end];
      const extendedBefore = before === "S";
      const extendedAfter = after === "S";
      if (!extendedBefore && !extendedAfter) return true;
    }
  }
  return false;
}

/** 6개 이상 연속(장목) 여부 */
export function checkOverline(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  for (const [dx, dy] of DIRECTIONS) {
    const line = encodeLine(board, x, y, dx, dy, color, 6);
    if (/S{6,}/.test(line)) return true;
  }
  return false;
}

/** 해당 방향에 "사(四)" - 한 수로 5를 완성할 수 있는 형태가 있는지 */
function hasFourInDirection(
  board: Board,
  x: number,
  y: number,
  dx: number,
  dy: number,
  color: StoneColor
): boolean {
  const line = encodeLine(board, x, y, dx, dy, color, 5);
  // 길이 5 윈도우 중 S가 4개, .이 1개인 패턴 = 그 . 자리에 두면 5완성
  for (let start = 0; start <= line.length - 5; start++) {
    const window = line.slice(start, start + 5);
    const sCount = (window.match(/S/g) || []).length;
    const dotCount = (window.match(/\./g) || []).length;
    if (sCount === 4 && dotCount === 1) return true;
  }
  return false;
}

/** 해당 방향에 "열린 삼(활삼)" - 막히지 않은 삼이 있는지 (간이 구현) */
function hasOpenThreeInDirection(
  board: Board,
  x: number,
  y: number,
  dx: number,
  dy: number,
  color: StoneColor
): boolean {
  const line = encodeLine(board, x, y, dx, dy, color, 4); // 길이 9
  const patterns = [/\.SSS\.\./, /\.\.SSS\./, /\.S\.SS\./, /\.SS\.S\./];
  return patterns.some((re) => re.test(line));
}

/**
 * 흑돌 금수(禁手) 판정: 장목, 33(쌍삼), 44(쌍사)
 * 렌주 룰: 해당 수로 정확히 5를 완성하면(장목이 아닌 이상) 금수보다 승리가 우선한다.
 * 반환값: 금수면 그 이유 문자열, 금수가 아니면 null
 */
export function checkForbiddenMove(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): string | null {
  // 백돌에는 금수가 없다 (표준 렌주룰)
  if (color !== "black") return null;

  // 장목은 항상 금수 (5를 만들어도 무효)
  if (checkOverline(board, x, y, color)) return "장목(6목 이상)";

  // 정확히 5를 완성하면 금수보다 승리 우선
  if (checkExactFive(board, x, y, color)) return null;

  let fourCount = 0;
  let openThreeCount = 0;
  for (const [dx, dy] of DIRECTIONS) {
    if (hasFourInDirection(board, x, y, dx, dy, color)) fourCount++;
    if (hasOpenThreeInDirection(board, x, y, dx, dy, color)) openThreeCount++;
  }

  if (fourCount >= 2) return "44(쌍사)";
  if (openThreeCount >= 2) return "33(쌍삼)";
  return null;
}

/** 착수 후 승리 여부 (정확히 5 이상 - 백은 장목도 승리, 흑은 정확히 5만) */
export function checkWin(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  if (color === "white") {
    // 백은 장목 제한 없음: 5개 이상 연속이면 승리
    for (const [dx, dy] of DIRECTIONS) {
      const line = encodeLine(board, x, y, dx, dy, color, 6);
      if (/S{5,}/.test(line)) return true;
    }
    return false;
  }
  // 흑은 정확히 5만 승리 (장목은 금수라 이 함수 호출 전 이미 걸러짐)
  return checkExactFive(board, x, y, color);
}

export function isBoardFull(board: Board): boolean {
  return board.every((row) => row.every((cell) => cell !== null));
}
GOMOKU_FILE_EOF

mkdir -p "src/lib/game"
cat > "src/lib/game/mine.ts" << 'GOMOKU_FILE_EOF'
/**
 * 지뢰 모드 규칙
 * - 자신의 턴에 한 번, 상대에게 보이지 않는 지뢰를 한 칸에 설치할 수 있다.
 * - 지뢰는 설치 직후 상대의 다음 턴이 "종료"되면 사라진다.
 *   즉 설치한 턴 번호를 T라 하면, 상대 턴(T+1) 동안은 유효하고 T+2가 되면 소멸.
 * - 상대가 지뢰 칸에 착수하면 그 착수는 무효화되고(돌이 놓이지 않고) 턴만 상대에게서 다시 넘어간다.
 * - 직전에 자신이 지뢰를 설치했던 칸에는 곧바로 다시 지뢰를 설치할 수 없다.
 */

export const MINE_ACTIVE_TURNS = 1; // 설치 턴 이후 몇 번의 "상대 턴"까지 유효한지

export function computeMineExpiry(placedAtTurn: number): number {
  // 상대 턴(placedAtTurn + 1) 종료 시 소멸 -> expires_at_turn 은
  // "이 turn_number가 되면 이미 소멸된 것으로 간주"
  return placedAtTurn + MINE_ACTIVE_TURNS + 1;
}

export function isMineStillActive(
  expiresAtTurn: number,
  currentTurnNumber: number
): boolean {
  return currentTurnNumber < expiresAtTurn;
}

export function isSameCell(
  a: { x: number; y: number } | null | undefined,
  b: { x: number; y: number }
): boolean {
  if (!a) return false;
  return a.x === b.x && a.y === b.y;
}
GOMOKU_FILE_EOF

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

mkdir -p "src/lib/supabase"
cat > "src/lib/supabase/client.ts" << 'GOMOKU_FILE_EOF'
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
GOMOKU_FILE_EOF

mkdir -p "src/lib/supabase"
cat > "src/lib/supabase/server.ts" << 'GOMOKU_FILE_EOF'
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

cat > "tailwind.config.ts" << 'GOMOKU_FILE_EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        board: "#dcb35c",
      },
    },
  },
  plugins: [],
};
export default config;
GOMOKU_FILE_EOF

cat > "tsconfig.json" << 'GOMOKU_FILE_EOF'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
GOMOKU_FILE_EOF

echo "완료! 총 파일 수: 27"
echo "다음: npm install 을 실행하세요."