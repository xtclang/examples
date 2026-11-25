import { useLayoutEffect, useRef } from 'react';
import './Board.css';
import { Piece } from './Piece.jsx';

const FILES = 'abcdefgh';
const RANKS = [8, 7, 6, 5, 4, 3, 2, 1];
const ORDER = [0, 1, 2, 3, 4, 5, 6, 7];
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
 * `flipped` turns the board round so the other player sits at the bottom, as White does in a room.
 *
 * `moveKey` counts the moves played so far. When it goes up by exactly one, the piece that just
 * moved glides from where it started, hopping through every square of a multi-jump (`route`) --
 * so the other player's move is something you see happen, not a piece that has silently
 * teleported. A move the viewer has just made themselves is not replayed: its piece was already
 * drawn where it landed. Stepping backwards or jumping repaints at once.
 */
export default function Board({
  board,
  flipped = false,
  highlight = [],
  route = [],
  selected = null,
  targets = [],
  movable = null,
  onSelect = null,
  moveKey = null,
}) {
  const host = useRef(null);
  const previousKey = useRef(moveKey);
  const previousBoard = useRef(board);

  useLayoutEffect(() => {
    const prev = previousKey.current;
    previousKey.current = moveKey;
    if (moveKey === null || prev === null || moveKey !== prev + 1) return;
    if (highlight.length < 2 || reducedMotion() || !host.current) return;

    const [from, to] = highlight;

    // If the piece was already drawn on its destination, the viewer made this move themselves
    // (the board showed it landing while the server answered): do not play it a second time.
    const row = 8 - Number(to[1]);
    const col = FILES.indexOf(to[0]);
    if (previousBoard.current?.[row]?.[col]) return;

    const origin = host.current.querySelector(`[data-square="${from}"]`);
    const destination = host.current.querySelector(`[data-square="${to}"]`);
    const piece = destination?.querySelector('.piece');
    if (!origin || !piece || typeof piece.animate !== 'function') return;

    // The piece starts on the first square of its route and hops through the rest, ending where
    // it already is. Offsets are measured from the destination, which is where the piece is drawn.
    const b = destination.getBoundingClientRect();
    const squares = route.length >= 2 && route[0] === from && route[route.length - 1] === to ? route : [from, to];
    const frames = squares.map((square) => {
      const r = host.current.querySelector(`[data-square="${square}"]`)?.getBoundingClientRect() ?? b;
      return { transform: `translate(${r.left - b.left}px, ${r.top - b.top}px)` };
    });
    destination.classList.add('lifting');
    const glide = piece.animate(frames, {
      duration: GLIDE.duration + 170 * (squares.length - 2),
      easing: GLIDE.easing,
    });
    glide.onfinish = glide.oncancel = () => destination.classList.remove('lifting');
  }, [moveKey, highlight, route]);

  // Remember what was drawn, for the next move to compare with. Declared after the effect above
  // so that, when it runs, it still sees the previous render's board.
  useLayoutEffect(() => {
    previousBoard.current = board;
  });

  const rows = flipped ? [...ORDER].reverse() : ORDER;
  const cols = rows;
  const files = flipped ? [...FILES].reverse() : [...FILES];
  const ranks = flipped ? [...RANKS].reverse() : RANKS;

  return (
    <div className="board-frame">
      {/* The coordinates sit on the wooden rails, as on a real board. */}
      <div className="rail rail-files rail-top" aria-hidden="true">
        {files.map((f) => <span key={f}>{f}</span>)}
      </div>
      <div className="rail rail-files rail-bottom" aria-hidden="true">
        {files.map((f) => <span key={f}>{f}</span>)}
      </div>
      <div className="rail rail-ranks rail-left" aria-hidden="true">
        {ranks.map((r) => <span key={r}>{r}</span>)}
      </div>
      <div className="rail rail-ranks rail-right" aria-hidden="true">
        {ranks.map((r) => <span key={r}>{r}</span>)}
      </div>

      <div ref={host} className={onSelect ? 'board playable' : 'board'} role="grid" aria-label="Draughts board">
        {rows.map((row) =>
          cols.map((col) => {
            const cell = board[row][col];
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
            return (
              <div
                key={square}
                data-square={square}
                className={cls}
                role="gridcell"
                aria-label={`${square}, ${cell ? NAMES[cell] : 'empty'}${isTarget ? ', can move here' : ''}`}
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
                {cell && <Piece color={cell.toLowerCase()} king={cell === cell.toUpperCase()} />}
                {isTarget && <span className="target" aria-hidden="true" />}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
