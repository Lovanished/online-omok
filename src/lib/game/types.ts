export type StoneColor = "black" | "white";
export type Cell = StoneColor | null;
export type Board = Cell[][]; // board[y][x]

export type GameMode = "normal" | "mine" | "extreme";
export type RoomStatus = "waiting" | "playing" | "finished";

export type LastMoveType = "stone" | "mine" | "blocked";

export interface LastMove {
  type: LastMoveType;
  color: StoneColor;
  // stone, blocked 타입일 때만 좌표를 공개한다.
  // mine(지뢰 설치) 타입은 위치를 절대 공개하면 안 되므로 x,y를 넣지 않는다.
  x?: number;
  y?: number;
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
  winner: StoneColor | "draw" | null;
  board: Board;
  last_move: LastMove | null;
  turn_number: number;
  created_at: string;
  updated_at: string;
}

export interface PlayerRow {
  id: string;
  room_id: string;
  color: StoneColor;
  nickname: string;
  session_token: string;
}

export interface MoveResult {
  ok: boolean;
  error?: string;
  invalidatedByMine?: boolean;
  winner?: StoneColor | "draw" | null;
  board?: Board;
  nextTurn?: StoneColor;
  turnNumber?: number;
}
