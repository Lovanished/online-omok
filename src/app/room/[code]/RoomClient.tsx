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
