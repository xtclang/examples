// Solid glyphs for both sides; colour and outline tell them apart, which reads far better than
// the hollow outline glyphs at board size.
const GLYPHS = { k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟' };

const FILES = 'abcdefgh';

/**
 * Renders an 8x8 matrix of `{ type, color }` cells, rank 8 first.
 *
 * Read-only by default. Passing `onSelect` makes the squares clickable, and `selected` and
 * `targets` then show what is picked up and where it can go.
 */
export default function Board({
  board, flipped = false, highlight = [], selected = null, targets = [], onSelect = null,
}) {
  const ranks = flipped ? [...board].reverse() : board;
  return (
    <div className={onSelect ? 'board playable' : 'board'} role="grid" aria-label="Chess board">
      {ranks.map((rank, r) => {
        const cells = flipped ? [...rank].reverse() : rank;
        return cells.map((cell, c) => {
          const rowIdx = flipped ? 7 - r : r;
          const colIdx = flipped ? 7 - c : c;
          const square = FILES[colIdx] + (8 - rowIdx);
          const dark = (rowIdx + colIdx) % 2 === 1;
          const isTarget = targets.includes(square);
          const cls = [
            'square',
            dark ? 'dark' : 'light',
            highlight.includes(square) ? 'hl' : '',
            square === selected ? 'sel' : '',
          ].join(' ');

          const press = onSelect ? () => onSelect(square) : undefined;
          return (
            <div
              key={square}
              className={cls}
              role="gridcell"
              aria-label={`${square}${cell ? `, ${cell.color === 'w' ? 'white' : 'black'} ${cell.type}` : ', empty'}`}
              aria-selected={onSelect ? square === selected : undefined}
              tabIndex={onSelect ? 0 : undefined}
              onClick={press}
              onKeyDown={
                onSelect
                  ? (e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        press();
                      }
                    }
                  : undefined
              }
            >
              {c === 0 && <span className="coord rank">{square[1]}</span>}
              {r === 7 && <span className="coord file">{square[0]}</span>}
              {cell && <span className={`piece ${cell.color}`}>{GLYPHS[cell.type]}</span>}
              {isTarget && <span className={cell ? 'target capture' : 'target'} aria-hidden="true" />}
            </div>
          );
        });
      })}
    </div>
  );
}
