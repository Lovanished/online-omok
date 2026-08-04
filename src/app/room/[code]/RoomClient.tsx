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
