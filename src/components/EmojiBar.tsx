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
