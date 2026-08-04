"use client";

import { Board as BoardType, LastMove } from "@/lib/game/types";

interface Props {
  board: BoardType;
  lastMove: LastMove | null;
  disabled: boolean;
  onCellClick: (x: number, y: number) => void;
  placingMine?: boolean;
}

export default function Board({ board, lastMove, disabled, onCellClick, placingMine }: Props) {
  const size = board.length;

  return (
    <div
      className="inline-grid bg-board rounded-lg shadow-lg select-none touch-none"
      style={{
        gridTemplateColumns: `repeat(${size}, minmax(20px, 32px))`,
        gridTemplateRows: `repeat(${size}, minmax(20px, 32px))`,
        padding: "12px",
      }}
    >
      {board.map((row, y) =>
        row.map((cell, x) => {
          const isLast =
            lastMove &&
            lastMove.type !== "mine" &&
            lastMove.x === x &&
            lastMove.y === y;
          return (
            <button
              key={`${x}-${y}`}
              disabled={disabled || cell !== null}
              onClick={() => onCellClick(x, y)}
              className={`relative border border-black/30 flex items-center justify-center ${
                placingMine ? "hover:bg-red-400/40" : "hover:bg-black/10"
              } disabled:cursor-default`}
              aria-label={`${x},${y}`}
            >
              {cell && (
                <span
                  className={`block rounded-full ${
                    cell === "black" ? "bg-gray-900" : "bg-white border border-gray-400"
                  }`}
                  style={{ width: "78%", height: "78%" }}
                />
              )}
              {isLast && (
                <span className="absolute inset-0 border-2 border-amber-500 rounded-sm pointer-events-none" />
              )}
            </button>
          );
        })
      )}
    </div>
  );
}
