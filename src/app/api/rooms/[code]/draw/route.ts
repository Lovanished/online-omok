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
