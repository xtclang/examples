import { useLayoutEffect, useRef } from 'react';

// Solid glyphs for both sides; colour and outline tell them apart, which reads far better than
// the hollow outline glyphs at board size.
const GLYPHS = { k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟' };
const FILES = 'abcdefgh';
const NAMES = { k: 'king', q: 'queen', r: 'rook', b: 'bishop', n: 'knight', p: 'pawn' };

/** Strong ease-out: the piece leaves at once and settles softly. */
const GLIDE = { duration: 240, easing: 'cubic-bezier(0.23, 1, 0.32, 1)' };

const reducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

/**
 * Renders an 8x8 matrix of `{ type, color }` cells, rank 8 first.
 *
 * Read-only by default. With `onSelect` the squares become buttons, and `selected` and `targets`
 * show what is picked up and where it can go.
 *
 * `moveKey` counts the moves played so far. When it goes up by exactly one, the piece that just
 * moved glides from its origin square -- so the computer's reply is something you see happen,
 * not a piece that has silently teleported. Stepping backwards, jumping, or flipping the board
 * repaints at once.
 */
export default function Board({
  board,
  flipped = false,
  highlight = [],
  selected = null,
  targets = [],
  onSelect = null,
  moveKey = null,
}) {
  const host = useRef(null);
  const previousKey = useRef(moveKey);

  useLayoutEffect(() => {
    const prev = previousKey.current;
    previousKey.current = moveKey;
    if (moveKey === null || prev === null || moveKey !== prev + 1) return;
    if (highlight.length < 2 || reducedMotion() || !host.current) return;

    const [from, to] = highlight;
    const origin = host.current.querySelector(`[data-square="${from}"]`);
    const destination = host.current.querySelector(`[data-square="${to}"]`);
    const piece = destination?.querySelector('.piece');
    if (!origin || !piece || typeof piece.animate !== 'function') return;

    const a = origin.getBoundingClientRect();
    const b = destination.getBoundingClientRect();
    const dx = a.left - b.left;
    const dy = a.top - b.top;

    destination.classList.add('lifting');
    const glide = piece.animate(
      [{ transform: `translate(${dx}px, ${dy}px)` }, { transform: 'translate(0, 0)' }],
      GLIDE
    );
    glide.onfinish = glide.oncancel = () => destination.classList.remove('lifting');
  }, [moveKey, highlight]);

  const ranks = flipped ? [...board].reverse() : board;
  return (
    <div
      ref={host}
      className={onSelect ? 'board playable' : 'board'}
      role="grid"
      aria-label="Chess board"
    >
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
          const description = cell ? `${cell.color === 'w' ? 'white' : 'black'} ${NAMES[cell.type]}` : 'empty';
          return (
            <div
              key={square}
              data-square={square}
              className={cls}
              role="gridcell"
              aria-label={`${square}, ${description}${isTarget ? ', can move here' : ''}`}
              aria-selected={onSelect ? square === selected : undefined}
              tabIndex={onSelect ? 0 : undefined}
              onPointerDown={press}
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
