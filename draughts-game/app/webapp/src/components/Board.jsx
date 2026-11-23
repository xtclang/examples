import { useLayoutEffect, useRef } from 'react';
import './Board.css';

const FILES = 'abcdefgh';
const NAMES = { b: 'black man', B: 'black king', w: 'white man', W: 'white king' };

/** Strong ease-out: the piece leaves at once and settles softly. */
const GLIDE = { duration: 240, easing: 'cubic-bezier(0.23, 1, 0.32, 1)' };

const reducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

/**
 * Renders an 8x8 matrix of 'b' 'B' 'w' 'W' (or null), the top row first.
 *
 * Read-only by default. With `onSelect` the dark squares become buttons; `movable` marks the
 * pieces that can move, `selected` the one picked up, and `targets` where it can go.
 *
 * `moveKey` counts the moves played so far. When it goes up by exactly one, the piece that just
 * moved glides from where it started -- so the second player's move is something you see happen,
 * not a piece that has silently teleported. Stepping backwards or jumping repaints at once.
 */
export default function Board({
  board,
  highlight = [],
  selected = null,
  targets = [],
  movable = null,
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
    destination.classList.add('lifting');
    const glide = piece.animate(
      [{ transform: `translate(${a.left - b.left}px, ${a.top - b.top}px)` }, { transform: 'translate(0, 0)' }],
      GLIDE
    );
    glide.onfinish = glide.oncancel = () => destination.classList.remove('lifting');
  }, [moveKey, highlight]);

  return (
    <div ref={host} className={onSelect ? 'board playable' : 'board'} role="grid" aria-label="Draughts board">
      {board.map((rank, row) =>
        rank.map((cell, col) => {
          const square = FILES[col] + (8 - row);
          const dark = (row + col) % 2 === 1;
          const isTarget = targets.includes(square);
          const cls = [
            'square',
            dark ? 'dark' : 'light',
            highlight.includes(square) ? 'hl' : '',
            square === selected ? 'sel' : '',
            movable?.has(square) && !selected ? 'movable' : '',
          ].join(' ');

          const interactive = Boolean(onSelect) && dark;
          const press = interactive ? () => onSelect(square) : undefined;
          const description = cell ? NAMES[cell] : 'empty';
          return (
            <div
              key={square}
              data-square={square}
              className={cls}
              role="gridcell"
              aria-label={`${square}, ${description}${isTarget ? ', can move here' : ''}`}
              aria-selected={interactive ? square === selected : undefined}
              tabIndex={interactive ? 0 : undefined}
              onPointerDown={press}
              onKeyDown={
                interactive
                  ? (e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        press();
                      }
                    }
                  : undefined
              }
            >
              {col === 0 && <span className="coord rank">{8 - row}</span>}
              {row === 7 && <span className="coord file">{FILES[col]}</span>}
              {cell && (
                <span className={`piece ${cell.toLowerCase()}${cell === cell.toUpperCase() ? ' king' : ''}`} />
              )}
              {isTarget && <span className="target" aria-hidden="true" />}
            </div>
          );
        })
      )}
    </div>
  );
}
