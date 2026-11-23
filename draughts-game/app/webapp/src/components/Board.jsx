import { useLayoutEffect, useRef } from 'react';
import './Board.css';

const FILES = 'abcdefgh';
const RANKS = [8, 7, 6, 5, 4, 3, 2, 1];
const NAMES = { b: 'black man', B: 'black king', w: 'white man', W: 'white king' };

/** Strong ease-out: the piece leaves at once and settles softly. */
const GLIDE = { duration: 240, easing: 'cubic-bezier(0.23, 1, 0.32, 1)' };

const reducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

/** The crown on a king: a gold band with five points, outlined so it reads on both colours. */
function Crown() {
  return (
    <svg className="crown" viewBox="0 0 32 28" aria-hidden="true">
      <path
        d="M3 22 1.5 7.5 9.5 13 16 3l6.5 10 8-5.5L29 22z"
        fill="#f4c542"
        stroke="#7a5608"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <rect x="3" y="22.5" width="26" height="4" rx="1.6" fill="#e0a82a" stroke="#7a5608" strokeWidth="1.6" />
      <circle cx="1.8" cy="7.2" r="2" fill="#fff3b8" stroke="#7a5608" strokeWidth="1.2" />
      <circle cx="16" cy="3.2" r="2" fill="#fff3b8" stroke="#7a5608" strokeWidth="1.2" />
      <circle cx="30.2" cy="7.2" r="2" fill="#fff3b8" stroke="#7a5608" strokeWidth="1.2" />
    </svg>
  );
}

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
    <div className="board-frame">
      {/* The coordinates sit on the wooden rails, as on a real board. */}
      <div className="rail rail-files rail-top" aria-hidden="true">
        {[...FILES].map((f) => <span key={f}>{f}</span>)}
      </div>
      <div className="rail rail-files rail-bottom" aria-hidden="true">
        {[...FILES].map((f) => <span key={f}>{f}</span>)}
      </div>
      <div className="rail rail-ranks rail-left" aria-hidden="true">
        {RANKS.map((r) => <span key={r}>{r}</span>)}
      </div>
      <div className="rail rail-ranks rail-right" aria-hidden="true">
        {RANKS.map((r) => <span key={r}>{r}</span>)}
      </div>

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
                {cell && (
                  <span className={`piece ${cell.toLowerCase()}${cell === cell.toUpperCase() ? ' king' : ''}`}>
                    {cell === cell.toUpperCase() && <Crown />}
                  </span>
                )}
                {isTarget && <span className="target" aria-hidden="true" />}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
