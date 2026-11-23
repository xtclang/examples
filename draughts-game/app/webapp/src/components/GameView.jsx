import { useEffect, useState } from 'react';
import './Play.css';
import Board from './Board.jsx';
import { PieceIcon } from './Piece.jsx';
import { Skeleton, Thinking } from './ui.jsx';
import { boardAlong, moveSquares, toMatrix } from '../lib/play.js';
import { formatClock, LOW_MS, useClocks } from '../lib/clock.js';
import { play as playSound, useGameSounds } from '../lib/sound.js';

/** The moves so far as a scoresheet. Any move can be clicked to look at that position. */
function Scoresheet({ history, viewing, onView }) {
  if (!history.length) return null;
  const rows = [];
  for (let i = 0; i < history.length; i += 2) rows.push(i);
  return (
    <ol className="scoresheet" aria-label="Moves played">
      {rows.map((i) => (
        <li key={i}>
          <span className="no">{i / 2 + 1}.</span>
          {[i, i + 1].map((k) =>
            history[k] ? (
              <button
                key={k}
                className={viewing === k + 1 ? 'on' : ''}
                onClick={() => onView(k + 1)}
                aria-label={`Show the position after ${history[k].notation}`}
              >
                {history[k].notation}
              </button>
            ) : (
              <span key={k} />
            )
          )}
        </li>
      ))}
    </ol>
  );
}

export function GameSkeleton() {
  return (
    <div className="play">
      <div className="play-head">
        <Skeleton width="16rem" height="1.1rem" />
      </div>
      <div className="board board-skeleton">
        <Skeleton width="100%" height="100%" radius={8} />
      </div>
    </div>
  );
}

/** One player: their piece, their nickname, and how many pieces they have left. */
function PlayerTag({ color, name, pieces, active, side, thinking, clock }) {
  return (
    <div className={`player${active ? ' on' : ''}`} aria-current={active ? 'true' : undefined}>
      <PieceIcon color={color} size={22} />
      <span className="player-name">{name}</span>
      <span className="player-side">{side}</span>
      {thinking && <Thinking label="Computer thinking" />}
      {clock !== undefined && (
        <span
          className={`player-clock${active ? ' on' : ''}${clock.low ? ' low' : ''}`}
          role="timer"
          aria-label={`${name}'s time`}
        >
          {clock.text}
        </span>
      )}
      <span className="player-count" title="Pieces left">{pieces}</span>
    </div>
  );
}

/**
 * A game on the board: the two players, the board, the hint and the score sheet. Shared by the
 * single-player game and rooms, which differ only in who is allowed to move.
 *
 * @param state      the game, as either service sends it
 * @param selection  the picked squares (see useSelection)
 * @param playable   whether the board takes input right now
 * @param flipped    put White at the bottom (the White player's view in a room)
 * @param you        'Black' or 'White' if one side is the person looking; Null for a shared screen
 * @param computer   White is the computer
 * @param thinking   the computer is choosing its move
 * @param status     the status line
 * @param actions    buttons for the right of the status line
 * @param hint       what to say under the board while the game is live (a default if left out)
 */
export default function GameView({
  state,
  selection,
  playable,
  flipped = false,
  you = null,
  computer = false,
  thinking = false,
  status,
  actions,
  hint,
  error,
}) {
  const [viewing, setViewing] = useState(null);
  const moveCount = state.history.length;
  useEffect(() => setViewing(null), [moveCount]);

  const over = state.status !== 'Ongoing';
  const live = viewing === null;

  // Sounds: the moves and the result, whoever made them; a sound as a piece is picked up; and a
  // tick each second while your own clock is in its last ten.
  useGameSounds(state, you ?? (computer ? 'Black' : null));
  const picked = selection.path.length === 1 ? selection.path[0] : null;
  useEffect(() => {
    if (picked) playSound('select');
  }, [picked]);

  const clocks = useClocks(state);
  const yourSeconds = clocks && you ? Math.ceil(clocks[you] / 1000) : null;
  useEffect(() => {
    if (yourSeconds !== null && yourSeconds > 0 && yourSeconds <= 10 && clocks.running && state.turn === you) {
      playSound('tick');
    }
  }, [yourSeconds]); // eslint-disable-line react-hooks/exhaustive-deps
  const clockFor = (color) =>
    clocks ? { text: formatClock(clocks[color]), low: clocks[color] <= LOW_MS } : undefined;
  const past = live ? null : state.history[viewing - 1];
  const board = live ? boardAlong(toMatrix(state.board), selection.path) : toMatrix(past.boardAfter.match(/.{8}/g));
  const highlight = live ? moveSquares(state.lastMove) : moveSquares(past.path);
  const blacksTurn = state.turn === 'Black';

  const tags = {
    w: {
      color: 'w',
      name: state.whiteName,
      pieces: state.whitePieces,
      active: !over && !blacksTurn,
      side: computer ? 'Computer' : you === 'White' ? 'White · you' : 'White',
      thinking,
      clock: clockFor('White'),
    },
    b: {
      color: 'b',
      name: state.blackName,
      pieces: state.blackPieces,
      active: !over && blacksTurn,
      side: you === 'Black' ? 'Black · you · moves first' : 'Black · moves first',
      clock: clockFor('Black'),
    },
  };
  const [top, bottom] = flipped ? [tags.b, tags.w] : [tags.w, tags.b];

  const liveHint = hint ?? (
    over
      ? 'Game over.'
      : selection.path.length > 1
        ? 'Keep jumping: choose the next square.'
        : state.mustCapture
          ? 'A capture is compulsory. The pieces that can capture are ringed.'
          : 'Click a piece, then a highlighted square.'
  );

  return (
    <div className="play">
      <header className="play-head">
        <p className="play-status" aria-live="polite">
          <span className={`status-dot ${over ? 'over' : thinking ? 'busy' : 'ready'}`} aria-hidden="true" />
          {status ?? state.message}
        </p>
        {actions}
      </header>

      <PlayerTag {...top} />

      <div className="board-wrap">
        <Board
          board={board}
          flipped={flipped}
          highlight={highlight}
          selected={live ? selection.selected : null}
          targets={live ? selection.targets : []}
          movable={live && playable ? selection.movable : null}
          onSelect={live && playable ? selection.touch : null}
          moveKey={live ? moveCount : null}
        />
        {!live && (
          <div className="history-banner">
            <span>Viewing the position after move {viewing}</span>
            <button className="btn btn-solid btn-sm" onClick={() => setViewing(null)}>
              Back to the game
            </button>
          </div>
        )}
      </div>

      <PlayerTag {...bottom} />

      {error && <p className="error">{error}</p>}

      <p className="play-hint">{live ? liveHint : 'Click any move to look back; the game waits for you.'}</p>

      <Scoresheet history={state.history} viewing={viewing} onView={(k) => setViewing(k >= moveCount ? null : k)} />
    </div>
  );
}
