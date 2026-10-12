// Solid glyphs for both sides; colour and outline tell them apart, which reads far better than
// the hollow outline glyphs at board size.
const GLYPHS = { k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟' };

const FILES = 'abcdefgh';

// Renders a chess.js board() matrix (8x8, rank 8 first). Read-only.
export default function Board({ board, flipped = false, highlight = [] }) {
  const ranks = flipped ? [...board].reverse() : board;
  return (
    <div className="board" role="grid" aria-label="Chess board">
      {ranks.map((rank, r) => {
        const cells = flipped ? [...rank].reverse() : rank;
        return cells.map((cell, c) => {
          const rowIdx = flipped ? 7 - r : r;
          const colIdx = flipped ? 7 - c : c;
          const square = FILES[colIdx] + (8 - rowIdx);
          const dark = (rowIdx + colIdx) % 2 === 1;
          const cls = ['square', dark ? 'dark' : 'light', highlight.includes(square) ? 'hl' : '']
            .join(' ');
          return (
            <div key={square} className={cls} role="gridcell" aria-label={square}>
              {c === 0 && <span className="coord rank">{square[1]}</span>}
              {r === 7 && <span className="coord file">{square[0]}</span>}
              {cell && (
                <span className={`piece ${cell.color}`}>{GLYPHS[cell.type]}</span>
              )}
            </div>
          );
        });
      })}
    </div>
  );
}
