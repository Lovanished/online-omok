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
