#!/usr/bin/env bash
set -e
echo "오목 온라인 프로젝트 파일 생성/갱신 시작..."

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
- 방 생성 / 초대 코드로 참가 (흑돌·백돌은 방 생성 시 **랜덤**으로 배정)
- 실시간 채팅, 실시간 이모지 반응
- 🏳️ 기권, 🤝 무승부 제안(양쪽 동의 시 성립), 🔁 재대국(양쪽 동의 시 새 판 시작 +
  흑백 다시 랜덤 배정)
- 게임 모드
  - **일반 모드**: 표준 오목 규칙 + 흑돌 금수(장목, 33, 44)
  - **지뢰 모드**: 일반 모드 + 상대에게 보이지 않는 지뢰
  - **익스트림 모드**: 아직 규칙 미정 (스텁)

## 턴 구조
- 일반/익스트림 모드: 착수 한 번 = 한 턴
- 지뢰 모드: **① 돌 착수 → ② 지뢰 설치 칸 선택** 두 단계가 모두 끝나야 턴이
  상대에게 넘어갑니다. (`rooms.phase` 컬럼: `move` / `place_mine`)
  - 착수한 자리가 상대의 활성 지뢰였다면 → 착수 무효화 + 지뢰 설치 단계 없이 즉시 턴 종료
  - 지뢰는 `mines` 테이블에만 저장되고 RLS 정책이 아예 없어 브라우저(anon key)로는
    절대 조회 불가 → 서버 API(service role key)만 접근 가능
  - 설치 턴 T 기준 상대 턴(T+1)까지 유효, T+2에 자동 소멸
  - 직전에 자신이 설치한 지뢰와 같은 칸에는 곧바로 재설치 불가

## 흑백 랜덤 배정 / 재대국 / 기권 / 무승부
- **랜덤 배정**: 방 생성 시 호스트의 색이 50:50으로 랜덤 결정되고, 참가자는 나머지 색을
  받습니다. 재대국이 성사될 때마다 다시 랜덤으로 재배정됩니다.
- 이를 위해 `players` 테이블은 "고정 신분"인 `seat`(host/guest)과 "이번 판의 색"인
  `color`(black/white)를 분리해서 저장합니다. 색이 바뀔 수 있으므로, 새 판이
  시작되면(최초 입장 포함) 클라이언트가 `/api/rooms/[code]/me`를 호출해 자신의
  현재 색을 서버에서 다시 확인합니다.
- **기권**: 클릭 즉시 상대 승리로 게임 종료.
- **무승부**: 한쪽이 제안 → 상대가 수락해야 성립. 제안자는 응답 전까지 취소 가능,
  상대는 거절 가능.
- **재대국**: 게임 종료 후 양쪽이 모두 "재대국 신청"을 눌러야 새 판이 시작됩니다.
  새 판은 보드/턴/지뢰를 전부 초기화하고 흑백을 다시 랜덤 배정합니다.

> 참고: 렌주 금수(33/44) 판정 로직(`src/lib/game/gomoku.ts`)은 실전에서 흔히 쓰이는
> 패턴 매칭 방식의 간이 구현입니다. 대부분의 상황에서 정확하지만, 아주 드문 복합
> 패턴 엣지 케이스까지 100% 커버하진 않을 수 있어 실제 사용 전 테스트를 권장합니다.

## 로컬 개발 준비 (또는 Codespaces에서 그대로)

### 1. 패키지 설치
```bash
npm install
```

### 2. Supabase 프로젝트 준비
- **새로 시작하는 경우**: SQL Editor에서 `supabase/schema.sql` 전체 실행
- **이전 버전을 이미 쓰고 있던 경우**: `supabase/migrations/` 안의 파일을
  번호 순서대로(002, 003) 실행 (이미 적용한 파일은 다시 실행해도 안전하게
  설계되어 있습니다)
- Project Settings > API 에서 URL / anon key / service role key 확인

### 3. 환경변수
```bash
cp .env.example .env.local
```
값 채워넣기.

### 4. 개발 서버
```bash
npm run dev
```

## GitHub / Vercel
이전과 동일합니다.
```bash
git add -A
git commit -m "feat: 재대국/랜덤 흑백/기권/무승부 추가"
git push
```
Vercel 프로젝트의 Environment Variables는 이미 등록되어 있다면 추가 작업 없이
다음 배포에 자동 반영됩니다.

## 프로젝트 구조 (요약)
```
src/app/api/rooms/route.ts              방 생성 (흑백 랜덤)
src/app/api/rooms/[code]/join           참가 (남은 색 자동 배정)
src/app/api/rooms/[code]/me             내 현재 색/좌석 조회
src/app/api/rooms/[code]/move           착수 (금수/지뢰 판정)
src/app/api/rooms/[code]/mine           지뢰 설치 (착수 다음 단계)
src/app/api/rooms/[code]/resign         기권
src/app/api/rooms/[code]/draw           무승부 제안/수락/거절/취소
src/app/api/rooms/[code]/rematch        재대국 요청/성사(흑백 재배정)
src/lib/game/                           보드 로직, 타입
src/lib/supabase/                       브라우저/서버 클라이언트
src/app/room/[code]/RoomClient.tsx      실제 게임 화면
supabase/schema.sql                     최신 전체 스키마
supabase/migrations/                    기존 DB에 증분 적용할 SQL
```

## 알려진 제한사항
- 가벼운 `session_token` 기반 식별이라 로컬스토리지를 지우면 새 플레이어로 인식됩니다.
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

mkdir -p "src/app/api/rooms/[code]/draw"
cat > "src/app/api/rooms/[code]/draw/route.ts" << 'GOMOKU_FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import { Seat } from "@/lib/game/types";

type DrawAction = "offer" | "accept" | "decline" | "cancel";

export async function POST(
  req: NextRequest,
  { params }: { params: { code: string } }
) {
  const body = await req.json().catch(() => ({}));
  const { sessionToken, action } = body as {
    sessionToken?: string;
    action?: DrawAction;
  };
  if (!sessionToken || !["offer", "accept", "decline", "cancel"].includes(action || "")) {
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
    return NextResponse.json({ error: "진행 중인 게임이 없습니다." }, { status: 409 });
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
  const offeredBy: Seat | null = room.draw_offered_by;

  let updates: Record<string, unknown> | null = null;

  if (action === "offer") {
    if (offeredBy) {
      return NextResponse.json({ error: "이미 무승부 제안이 진행 중입니다." }, { status: 409 });
    }
    updates = { draw_offered_by: seat };
  } else if (action === "cancel") {
    if (offeredBy !== seat) {
      return NextResponse.json({ error: "취소할 제안이 없습니다." }, { status: 409 });
    }
    updates = { draw_offered_by: null };
  } else if (action === "decline") {
    if (!offeredBy || offeredBy === seat) {
      return NextResponse.json({ error: "거절할 제안이 없습니다." }, { status: 409 });
    }
    updates = { draw_offered_by: null };
  } else if (action === "accept") {
    if (!offeredBy || offeredBy === seat) {
      return NextResponse.json({ error: "수락할 제안이 없습니다." }, { status: 409 });
    }
    updates = { draw_offered_by: null, status: "finished", winner: "draw" };
  }

  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update(updates!)
    .eq("id", room.id)
    .select()
    .single();

  if (updateError || !updatedRoom) {
    return NextResponse.json({ error: updateError?.message ?? "업데이트 실패" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, room: updatedRoom });
}
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/join"
cat > "src/app/api/rooms/[code]/join/route.ts" << 'GOMOKU_FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import { StoneColor } from "@/lib/game/types";

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
    return NextResponse.json({ error: "이미 인원이 가득 찬 방입니다." }, { status: 409 });
  }

  const { data: hostPlayer, error: hostError } = await supabase
    .from("players")
    .select("*")
    .eq("room_id", room.id)
    .eq("seat", "host")
    .single();
  if (hostError || !hostPlayer) {
    return NextResponse.json({ error: "방 정보를 확인할 수 없습니다." }, { status: 500 });
  }

  const guestColor: StoneColor = hostPlayer.color === "black" ? "white" : "black";

  const { data: player, error: playerError } = await supabase
    .from("players")
    .insert({ room_id: room.id, seat: "guest", color: guestColor, nickname })
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
    color: guestColor,
    isHost: false,
  });
}
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/me"
cat > "src/app/api/rooms/[code]/me/route.ts" << 'GOMOKU_FILE_EOF'
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
      .eq("owner_color", nextColor)
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

mkdir -p "src/app/api/rooms/[code]/rematch"
cat > "src/app/api/rooms/[code]/rematch/route.ts" << 'GOMOKU_FILE_EOF'
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
GOMOKU_FILE_EOF

mkdir -p "src/app/api/rooms/[code]/resign"
cat > "src/app/api/rooms/[code]/resign/route.ts" << 'GOMOKU_FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";
import { StoneColor } from "@/lib/game/types";

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
  if (room.status !== "playing") {
    return NextResponse.json({ error: "진행 중인 게임이 없습니다." }, { status: 409 });
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

  const myColor: StoneColor = player.color;
  const winner: StoneColor = myColor === "black" ? "white" : "black";

  const { data: updatedRoom, error: updateError } = await supabase
    .from("rooms")
    .update({
      status: "finished",
      winner,
      draw_offered_by: null,
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
import { GameMode, StoneColor } from "@/lib/game/types";

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
  const hostColor: StoneColor = Math.random() < 0.5 ? "black" : "white";

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
    .insert({ room_id: room.id, seat: "host", color: hostColor, nickname })
    .select()
    .single();

  if (playerError || !player) {
    return NextResponse.json({ error: playerError?.message ?? "플레이어 생성 실패" }, { status: 500 });
  }

  return NextResponse.json({
    room,
    sessionToken: player.session_token,
    color: hostColor,
    isHost: true,
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
        JSON.stringify({
          sessionToken: data.sessionToken,
          color: data.color,
          nickname,
          isHost: true,
        })
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
        JSON.stringify({
          sessionToken: data.sessionToken,
          color: data.color,
          nickname,
          isHost: false,
        })
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

        <p className="text-center text-xs text-gray-500">
          방을 만들면 흑돌/백돌은 랜덤으로 배정됩니다.
        </p>

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

import { useEffect, useRef, useState } from "react";
import { useRoomRealtime } from "@/hooks/useRoomRealtime";
import { RoomRow, Seat } from "@/lib/game/types";
import Board from "@/components/Board";
import Chat from "@/components/Chat";
import EmojiBar from "@/components/EmojiBar";
import { Session } from "./page";

const MODE_LABEL: Record<string, string> = {
  normal: "일반 모드",
  mine: "지뢰 모드",
  extreme: "익스트림 모드 (준비 중)",
};

export default function RoomClient({
  initialRoom,
  initialSession,
  code,
}: {
  initialRoom: RoomRow;
  initialSession: Session;
  code: string;
}) {
  const { room, messages, emojiEvents, sendChat, sendEmoji } = useRoomRealtime(initialRoom);
  const [session, setSession] = useState<Session>(initialSession);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const prevStatusRef = useRef<string>(initialRoom.status);

  const mySeat: Seat = session.isHost ? "host" : "guest";
  const opponentSeat: Seat = session.isHost ? "guest" : "host";

  const isMyTurn = room.current_turn === session.color && room.status === "playing";
  const waitingForOpponent = room.status === "waiting";
  const mustPlaceMine = room.mode === "mine" && room.phase === "place_mine" && isMyTurn;
  const opponentIsPlacingMine =
    room.mode === "mine" && room.phase === "place_mine" && !isMyTurn && room.status === "playing";

  const opponentNickname =
    session.isHost ? room.guest_nickname : room.host_nickname;
  const myNickname = session.nickname;

  // 새 판이 시작되면(재대국 성사 또는 최초 입장) 내 색이 랜덤 재배정되었을 수 있으므로
  // 서버에 내 현재 색을 다시 물어본다.
  useEffect(() => {
    const justStarted =
      prevStatusRef.current !== "playing" && room.status === "playing" && room.turn_number === 0;
    prevStatusRef.current = room.status;
    if (!justStarted) return;

    (async () => {
      try {
        const res = await fetch(`/api/rooms/${code}/me`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ sessionToken: session.sessionToken }),
        });
        const data = await res.json();
        if (res.ok) {
          const updated = { ...session, color: data.color };
          setSession(updated);
          localStorage.setItem(`gomoku:${code}`, JSON.stringify(updated));
        }
      } catch {
        // 조용히 무시 - 다음 렌더/새로고침 때 다시 시도됨
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [room.status, room.turn_number]);

  async function call(endpoint: string, extra: Record<string, unknown> = {}) {
    setBusy(true);
    setActionError(null);
    try {
      const res = await fetch(`/api/rooms/${code}/${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionToken: session.sessionToken, ...extra }),
      });
      const data = await res.json();
      if (!res.ok) {
        setActionError(data.error);
        return null;
      }
      if (data.myColor) {
        const updated = { ...session, color: data.myColor };
        setSession(updated);
        localStorage.setItem(`gomoku:${code}`, JSON.stringify(updated));
      }
      return data;
    } finally {
      setBusy(false);
    }
  }

  async function handleCellClick(x: number, y: number) {
    if (!isMyTurn || busy) return;
    await call(mustPlaceMine ? "mine" : "move", { x, y });
  }

  async function handleResign() {
    if (busy) return;
    if (!confirm("정말로 기권하시겠습니까?")) return;
    await call("resign");
  }

  async function handleDraw(action: "offer" | "accept" | "decline" | "cancel") {
    if (busy) return;
    await call("draw", { action });
  }

  async function handleRematch() {
    if (busy) return;
    await call("rematch");
  }

  const myRematchRequested =
    mySeat === "host" ? room.rematch_host_requested : room.rematch_guest_requested;
  const opponentRematchRequested =
    opponentSeat === "host" ? room.rematch_host_requested : room.rematch_guest_requested;

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
          <p className="text-gray-400">상대: {opponentNickname ?? "대기 중..."}</p>
        </div>
      </div>

      {waitingForOpponent && (
        <p className="text-amber-300">
          상대가 참가하길 기다리는 중입니다. 방 코드를 공유해보세요: <b>{room.code}</b>
        </p>
      )}

      {room.status === "finished" && (
        <div className="flex flex-col items-center gap-3">
          <p className="text-lg font-bold text-amber-300">
            {room.winner === "draw"
              ? "무승부입니다."
              : `${room.winner === "black" ? "흑" : "백"} 승리!`}
          </p>
          <button
            onClick={handleRematch}
            disabled={busy || myRematchRequested}
            className="px-5 py-2 rounded-lg bg-amber-500 hover:bg-amber-400 disabled:opacity-50 font-semibold text-gray-900"
          >
            {myRematchRequested ? "상대의 수락을 기다리는 중..." : "🔁 재대국 신청"}
          </button>
          {opponentRematchRequested && !myRematchRequested && (
            <p className="text-emerald-400 text-sm">
              상대가 재대국을 신청했습니다! 위 버튼을 눌러 수락하세요.
            </p>
          )}
        </div>
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

      {room.status === "playing" && (
        <div className="flex flex-wrap items-center justify-center gap-3">
          <button
            onClick={handleResign}
            disabled={busy}
            className="px-4 py-2 rounded-lg bg-red-600/80 hover:bg-red-600 disabled:opacity-50 font-semibold text-sm"
          >
            🏳️ 기권
          </button>

          {!room.draw_offered_by && (
            <button
              onClick={() => handleDraw("offer")}
              disabled={busy}
              className="px-4 py-2 rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-50 font-semibold text-sm"
            >
              🤝 무승부 제안
            </button>
          )}

          {room.draw_offered_by === mySeat && (
            <button
              onClick={() => handleDraw("cancel")}
              disabled={busy}
              className="px-4 py-2 rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-50 font-semibold text-sm"
            >
              무승부 제안 취소 (상대 응답 대기 중)
            </button>
          )}

          {room.draw_offered_by === opponentSeat && (
            <div className="flex items-center gap-2 bg-gray-800 rounded-lg px-3 py-2">
              <span className="text-sm text-amber-300">
                {opponentNickname ?? "상대"}가 무승부를 제안했습니다.
              </span>
              <button
                onClick={() => handleDraw("accept")}
                disabled={busy}
                className="px-3 py-1 rounded bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-sm font-semibold"
              >
                수락
              </button>
              <button
                onClick={() => handleDraw("decline")}
                disabled={busy}
                className="px-3 py-1 rounded bg-gray-600 hover:bg-gray-500 disabled:opacity-50 text-sm font-semibold"
              >
                거절
              </button>
            </div>
          )}
        </div>
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
import { RoomRow, StoneColor } from "@/lib/game/types";
import RoomClient from "./RoomClient";

export interface Session {
  sessionToken: string;
  color: StoneColor;
  nickname: string;
  isHost: boolean;
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
    const s: Session = {
      sessionToken: data.sessionToken,
      color: data.color,
      nickname,
      isHost: false,
    };
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

  return <RoomClient initialRoom={room} initialSession={session} code={code} />;
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
          const isLast = lastMove && lastMove.x === x && lastMove.y === y;
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
 */
export function checkForbiddenMove(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): string | null {
  if (color !== "black") return null;

  if (checkOverline(board, x, y, color)) return "장목(6목 이상)";

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

/** 착수 후 승리 여부 (백은 장목도 승리, 흑은 정확히 5만) */
export function checkWin(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  if (color === "white") {
    for (const [dx, dy] of DIRECTIONS) {
      const line = encodeLine(board, x, y, dx, dy, color, 6);
      if (/S{5,}/.test(line)) return true;
    }
    return false;
  }
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
 * - 지뢰 모드에서 한 턴은 ① 돌 착수 -> ② 지뢰 설치 칸 선택 두 단계로 이루어진다.
 * - 지뢰는 설치 직후 상대의 다음 턴이 "종료"되면 사라진다.
 *   설치한 턴 번호를 T라 하면, 상대 턴(T+1) 동안은 유효하고 T+2가 되면 소멸.
 * - 상대가 지뢰 칸에 착수하면 그 착수는 무효화되고(돌이 놓이지 않고) 지뢰 설치
 *   단계 없이 곧바로 턴만 상대에게서 다시 넘어간다.
 * - 직전에 자신이 지뢰를 설치했던 칸에는 곧바로 다시 지뢰를 설치할 수 없다.
 */

export const MINE_ACTIVE_TURNS = 1;

export function computeMineExpiry(placedAtTurn: number): number {
  return placedAtTurn + MINE_ACTIVE_TURNS + 1;
}

export function isMineStillActive(
  expiresAtTurn: number,
  currentTurnNumber: number
): boolean {
  return currentTurnNumber < expiresAtTurn;
}
GOMOKU_FILE_EOF

mkdir -p "src/lib/game"
cat > "src/lib/game/types.ts" << 'GOMOKU_FILE_EOF'
export type StoneColor = "black" | "white";
export type Cell = StoneColor | null;
export type Board = Cell[][]; // board[y][x]

export type GameMode = "normal" | "mine" | "extreme";
export type RoomStatus = "waiting" | "playing" | "finished";
export type Seat = "host" | "guest";

export type LastMoveType = "stone" | "blocked";

export interface LastMove {
  type: LastMoveType;
  color: StoneColor;
  x: number;
  y: number;
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
  draw_offered_by: Seat | null;
  rematch_host_requested: boolean;
  rematch_guest_requested: boolean;
  created_at: string;
  updated_at: string;
}

export interface PlayerRow {
  id: string;
  room_id: string;
  seat: Seat;
  color: StoneColor;
  nickname: string;
  session_token: string;
}
GOMOKU_FILE_EOF

mkdir -p "src/lib/supabase"
cat > "src/lib/supabase/client.ts" << 'GOMOKU_FILE_EOF'
"use client";

import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

// 브라우저(클라이언트)에서 쓰는 인스턴스: anon key만 사용, RLS 정책을 그대로 따른다.
// players/mines 테이블은 select 정책이 없으므로 이 클라이언트로는 절대 조회되지 않는다.
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

mkdir -p "supabase/migrations"
cat > "supabase/migrations/002_add_phase.sql" << 'GOMOKU_FILE_EOF'
-- 이미 supabase/schema.sql(v1)을 실행해서 rooms 테이블이 이미 있다면,
-- Supabase SQL Editor에서 이 파일을 추가로 실행하세요.
-- (schema.sql을 처음부터 새로 실행하는 경우에는 필요 없습니다 - 이미 포함되어 있음)

alter table rooms
  add column if not exists phase text not null default 'move';

alter table rooms
  drop constraint if exists rooms_phase_check;

alter table rooms
  add constraint rooms_phase_check check (phase in ('move', 'place_mine'));
GOMOKU_FILE_EOF

mkdir -p "supabase/migrations"
cat > "supabase/migrations/003_add_rematch_draw_seat.sql" << 'GOMOKU_FILE_EOF'
-- 재대국 / 랜덤 흑백 배정 / 기권 / 무승부 기능을 위한 마이그레이션.
-- schema.sql(v2)을 처음부터 새로 실행하는 경우에는 필요 없습니다.
-- 예전 DB(001, 002만 적용된 상태)에 적용할 때만 실행하세요.

-- ---- players: seat(고정 신분) 추가, color unique 제약을 seat unique로 교체 ----
alter table players
  add column if not exists seat text;

-- 기존 규칙(호스트=black, 게스트=white)을 그대로 백필
update players set seat = case when color = 'black' then 'host' else 'guest' end
where seat is null;

alter table players
  alter column seat set not null;

alter table players
  drop constraint if exists players_seat_check;
alter table players
  add constraint players_seat_check check (seat in ('host', 'guest'));

-- 판마다 색이 랜덤으로 재배정되므로 더 이상 "방 안에서 색은 유일하다"를
-- DB 제약으로 강제하지 않는다 (재대국 시 색 스왑 과정에서 일시적으로
-- 중복될 수 있음). 대신 seat는 방 안에서 유일해야 한다.
alter table players
  drop constraint if exists players_room_id_color_key;

alter table players
  drop constraint if exists players_room_id_seat_key;
alter table players
  add constraint players_room_id_seat_key unique (room_id, seat);

-- ---- rooms: 무승부 제안 / 재대국 요청 플래그 ----
alter table rooms
  add column if not exists draw_offered_by text;

alter table rooms
  drop constraint if exists rooms_draw_offered_by_check;
alter table rooms
  add constraint rooms_draw_offered_by_check check (draw_offered_by in ('host', 'guest'));

alter table rooms
  add column if not exists rematch_host_requested boolean not null default false;
alter table rooms
  add column if not exists rematch_guest_requested boolean not null default false;

-- ---- players 테이블에 대한 기존 공개 select 정책이 있었다면 제거 ----
-- (session_token이 그대로 노출되는 보안 문제가 있었음)
drop policy if exists "players_select_all" on players;
GOMOKU_FILE_EOF

mkdir -p "supabase"
cat > "supabase/schema.sql" << 'GOMOKU_FILE_EOF'
-- ============================================================
-- 오목 온라인 - Supabase 스키마 (v2: 재대국/랜덤 흑백/기권/무승부 포함)
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요.
-- 이미 예전 버전을 실행한 적이 있다면 supabase/migrations/ 안의 파일들을
-- 번호 순서대로 실행하는 편이 더 안전합니다 (README 참고).
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- rooms: 게임방
-- ---------------------------------------------------------------
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,                -- 6자리 초대 코드
  mode text not null default 'normal',      -- normal | mine | extreme
  status text not null default 'waiting',   -- waiting | playing | finished
  board_size int not null default 15,
  host_nickname text not null,
  guest_nickname text,
  current_turn text default 'black',        -- black | white
  phase text not null default 'move' check (phase in ('move', 'place_mine')),
                                             -- 지뢰 모드 전용: 'move'=착수 대기,
                                             -- 'place_mine'=방금 착수한 플레이어가
                                             -- 같은 턴에 지뢰 설치 칸을 골라야 함
  winner text,                              -- black | white | draw | null
  board jsonb not null default '[]'::jsonb, -- 15x15 돌 배치 (공개 정보만)
  last_move jsonb,                          -- {type,x,y,color}
  turn_number int not null default 0,
  draw_offered_by text check (draw_offered_by in ('host', 'guest')),
  rematch_host_requested boolean not null default false,
  rematch_guest_requested boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- players: 방에 접속한 플레이어
-- seat(host/guest)는 방을 만들었는지/참가했는지를 나타내는 "고정 신분"이고,
-- color(black/white)는 판마다 랜덤으로 재배정되는 "이번 판의 색"이다.
-- ---------------------------------------------------------------
create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  seat text not null check (seat in ('host', 'guest')),
  color text not null check (color in ('black', 'white')),
  nickname text not null,
  session_token uuid not null default gen_random_uuid(), -- 클라이언트가 보관, 본인 인증용
  created_at timestamptz not null default now(),
  unique (room_id, seat)
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

-- players: session_token이 들어있는 민감한 테이블이므로 클라이언트(anon key)에는
-- 어떤 select 정책도 주지 않는다. 필요한 공개 정보(닉네임/색상)는 rooms 테이블의
-- host_nickname/guest_nickname 과, 클라이언트가 이미 들고 있는 자기 세션으로 충분하고,
-- "내 색상 갱신"은 /api/rooms/[code]/me 서버 API(service role)를 통해서만 조회한다.

-- chat_messages: 누구나 읽기/쓰기 가능 (방 코드 기반 공개 채팅)
create policy "chat_select_all" on chat_messages for select using (true);
create policy "chat_insert_all" on chat_messages for insert with check (true);

-- mines: 어떤 정책도 만들지 않음 -> 클라이언트(anon key)는 절대 조회 불가.
-- service role key(API route)는 RLS를 우회하므로 서버에서만 접근 가능.

-- ---------------------------------------------------------------
-- Realtime 활성화
-- ---------------------------------------------------------------
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table chat_messages;

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

echo "완료! 총 파일 수: 33"