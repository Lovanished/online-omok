import { Board, Cell, StoneColor } from "./types";

export const BOARD_SIZE = 15;

export function createEmptyBoard(size = BOARD_SIZE): Board {
  return Array.from({ length: size }, () => Array<Cell>(size).fill(null));
}

export function inBounds(board: Board, x: number, y: number): boolean {
  return y >= 0 && y < board.length && x >= 0 && x < board[0].length;
}

export function cloneBoard(board: Board): Board {
  return board.map((row) => [...row]);
}

const DIRECTIONS: [number, number][] = [
  [1, 0], // 가로
  [0, 1], // 세로
  [1, 1], // 대각선 \
  [1, -1], // 대각선 /
];

/**
 * (x,y) 기준 한 방향으로 뻗은 라인을 문자열로 인코딩한다.
 * 'S' = 기준 돌 색과 동일, 'B' = 상대 돌 또는 보드 밖(막힘), '.' = 빈칸
 * radius 만큼 좌우로 뻗어서 문자열을 만들고, 중앙 인덱스(=radius)가 (x,y) 위치.
 */
function encodeLine(
  board: Board,
  x: number,
  y: number,
  dx: number,
  dy: number,
  color: StoneColor,
  radius: number
): string {
  let out = "";
  for (let i = -radius; i <= radius; i++) {
    const cx = x + dx * i;
    const cy = y + dy * i;
    if (i === 0) {
      out += "S"; // 가정: 이 자리에 방금 돌을 놓았다고 가정
      continue;
    }
    if (!inBounds(board, cx, cy)) {
      out += "B";
      continue;
    }
    const cell = board[cy][cx];
    if (cell === null) out += ".";
    else if (cell === color) out += "S";
    else out += "B";
  }
  return out;
}

/** 정확히 5개 연속(장목 아님)인지 확인 */
export function checkExactFive(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  for (const [dx, dy] of DIRECTIONS) {
    const line = encodeLine(board, x, y, dx, dy, color, 5);
    // 5연속 S가 있고, 그 앞뒤가 S가 아니면(=6개 이상 아니면) 정확한 5
    const re = /S{5}/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(line))) {
      const start = m.index;
      const end = start + 5;
      const before = line[start - 1];
      const after = line[end];
      const extendedBefore = before === "S";
      const extendedAfter = after === "S";
      if (!extendedBefore && !extendedAfter) return true;
    }
  }
  return false;
}

/** 6개 이상 연속(장목) 여부 */
export function checkOverline(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  for (const [dx, dy] of DIRECTIONS) {
    const line = encodeLine(board, x, y, dx, dy, color, 6);
    if (/S{6,}/.test(line)) return true;
  }
  return false;
}

/** 해당 방향에 "사(四)" - 한 수로 5를 완성할 수 있는 형태가 있는지 */
function hasFourInDirection(
  board: Board,
  x: number,
  y: number,
  dx: number,
  dy: number,
  color: StoneColor
): boolean {
  const line = encodeLine(board, x, y, dx, dy, color, 5);
  // 길이 5 윈도우 중 S가 4개, .이 1개인 패턴 = 그 . 자리에 두면 5완성
  for (let start = 0; start <= line.length - 5; start++) {
    const window = line.slice(start, start + 5);
    const sCount = (window.match(/S/g) || []).length;
    const dotCount = (window.match(/\./g) || []).length;
    if (sCount === 4 && dotCount === 1) return true;
  }
  return false;
}

/** 해당 방향에 "열린 삼(활삼)" - 막히지 않은 삼이 있는지 (간이 구현) */
function hasOpenThreeInDirection(
  board: Board,
  x: number,
  y: number,
  dx: number,
  dy: number,
  color: StoneColor
): boolean {
  const line = encodeLine(board, x, y, dx, dy, color, 4); // 길이 9
  const patterns = [/\.SSS\.\./, /\.\.SSS\./, /\.S\.SS\./, /\.SS\.S\./];
  return patterns.some((re) => re.test(line));
}

/**
 * 흑돌 금수(禁手) 판정: 장목, 33(쌍삼), 44(쌍사)
 * 렌주 룰: 해당 수로 정확히 5를 완성하면(장목이 아닌 이상) 금수보다 승리가 우선한다.
 * 반환값: 금수면 그 이유 문자열, 금수가 아니면 null
 */
export function checkForbiddenMove(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): string | null {
  // 백돌에는 금수가 없다 (표준 렌주룰)
  if (color !== "black") return null;

  // 장목은 항상 금수 (5를 만들어도 무효)
  if (checkOverline(board, x, y, color)) return "장목(6목 이상)";

  // 정확히 5를 완성하면 금수보다 승리 우선
  if (checkExactFive(board, x, y, color)) return null;

  let fourCount = 0;
  let openThreeCount = 0;
  for (const [dx, dy] of DIRECTIONS) {
    if (hasFourInDirection(board, x, y, dx, dy, color)) fourCount++;
    if (hasOpenThreeInDirection(board, x, y, dx, dy, color)) openThreeCount++;
  }

  if (fourCount >= 2) return "44(쌍사)";
  if (openThreeCount >= 2) return "33(쌍삼)";
  return null;
}

/** 착수 후 승리 여부 (정확히 5 이상 - 백은 장목도 승리, 흑은 정확히 5만) */
export function checkWin(
  board: Board,
  x: number,
  y: number,
  color: StoneColor
): boolean {
  if (color === "white") {
    // 백은 장목 제한 없음: 5개 이상 연속이면 승리
    for (const [dx, dy] of DIRECTIONS) {
      const line = encodeLine(board, x, y, dx, dy, color, 6);
      if (/S{5,}/.test(line)) return true;
    }
    return false;
  }
  // 흑은 정확히 5만 승리 (장목은 금수라 이 함수 호출 전 이미 걸러짐)
  return checkExactFive(board, x, y, color);
}

export function isBoardFull(board: Board): boolean {
  return board.every((row) => row.every((cell) => cell !== null));
}
