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
