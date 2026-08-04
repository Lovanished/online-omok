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
