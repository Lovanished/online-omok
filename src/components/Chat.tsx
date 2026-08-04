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
