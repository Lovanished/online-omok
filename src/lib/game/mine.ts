/**
 * 지뢰 모드 규칙
 * - 자신의 턴에 한 번, 상대에게 보이지 않는 지뢰를 한 칸에 설치할 수 있다.
 * - 지뢰는 설치 직후 상대의 다음 턴이 "종료"되면 사라진다.
 *   즉 설치한 턴 번호를 T라 하면, 상대 턴(T+1) 동안은 유효하고 T+2가 되면 소멸.
 * - 상대가 지뢰 칸에 착수하면 그 착수는 무효화되고(돌이 놓이지 않고) 턴만 상대에게서 다시 넘어간다.
 * - 직전에 자신이 지뢰를 설치했던 칸에는 곧바로 다시 지뢰를 설치할 수 없다.
 */

export const MINE_ACTIVE_TURNS = 1; // 설치 턴 이후 몇 번의 "상대 턴"까지 유효한지

export function computeMineExpiry(placedAtTurn: number): number {
  // 상대 턴(placedAtTurn + 1) 종료 시 소멸 -> expires_at_turn 은
  // "이 turn_number가 되면 이미 소멸된 것으로 간주"
  return placedAtTurn + MINE_ACTIVE_TURNS + 1;
}

export function isMineStillActive(
  expiresAtTurn: number,
  currentTurnNumber: number
): boolean {
  return currentTurnNumber < expiresAtTurn;
}

export function isSameCell(
  a: { x: number; y: number } | null | undefined,
  b: { x: number; y: number }
): boolean {
  if (!a) return false;
  return a.x === b.x && a.y === b.y;
}
