/**
 * 지뢰 모드 규칙
 * - 지뢰 모드에서 한 턴은 ① 돌 착수 -> ② 지뢰 설치 칸 선택 두 단계로 이루어진다.
 * - 지뢰는 설치 직후 상대의 다음 턴이 "종료"되면 사라진다.
 *   설치한 턴 번호를 T라 하면, 상대 턴(T+1) 동안은 유효하고 T+2가 되면 소멸.
 * - 상대가 지뢰 칸에 착수하면 그 착수는 무효화되고(돌이 놓이지 않고) 지뢰 설치
 *   단계 없이 곧바로 턴만 상대에게서 다시 넘어간다.
 * - 직전에 자신이 지뢰를 설치했던 칸에는 곧바로 다시 지뢰를 설치할 수 없다.
 */

export const MINE_ACTIVE_TURNS = 1;

export function computeMineExpiry(placedAtTurn: number): number {
  return placedAtTurn + MINE_ACTIVE_TURNS + 1;
}

export function isMineStillActive(
  expiresAtTurn: number,
  currentTurnNumber: number
): boolean {
  return currentTurnNumber < expiresAtTurn;
}
