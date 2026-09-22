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
