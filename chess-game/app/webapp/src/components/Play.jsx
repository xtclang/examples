import Board from './Board.jsx';
import { moveSquares, toMatrix } from '../lib/play.js';
import { Skeleton, Thinking } from './ui.jsx';

const TIME_CONTROLS = [
  { label: 'No clock', ms: 0, inc: 0 },
  { label: '5 + 0', ms: 5 * 60_000, inc: 0 },
  { label: '10 + 5', ms: 10 * 60_000, inc: 5_000 },
];

const clock = (ms) => {
  if (!Number.isFinite(ms)) return '—';
  const total = Math.max(0, Math.round(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

/** The moves so far as a scoresheet. Any move can be clicked to look at that position. */
function Scoresheet({ moves, viewing, onView }) {
  if (!moves.length) return null;
  const rows = [];
  for (let i = 0; i < moves.length; i += 2) rows.push(i);
  return (
    <ol className="scoresheet" aria-label="Moves played">
      {rows.map((i) => (
        <li key={i}>
          <span className="no">{i / 2 + 1}.</span>
          {[i, i + 1].map((k) =>
            moves[k] ? (
              <button
                key={k}
                className={viewing === k + 1 ? 'on' : ''}
                onClick={() => onView(k + 1)}
                aria-label={`Show the position after ${moves[k].san}`}
              >
                {moves[k].san}
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

function PlaySkeleton() {
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

export default function Play({ play, viewing, onView }) {
  const { state, frames, selected, targets, error, thinking, playable, touch, restart, restarting } = play;

  if (!state) return error ? <p className="error">{error}</p> : <PlaySkeleton />;

  const live = viewing === null;
  const shown = live ? null : frames.positions[viewing];
  const tc = state.timeControl;
  const over = state.status !== 'Ongoing';

  const status = over
    ? state.message
    : thinking
      ? 'The engine is thinking'
      : playable
        ? 'Your move'
        : 'Waiting';

  return (
    <div className="play">
      <header className="play-head">
        <p className="play-status" aria-live="polite">
          <span className={`status-dot ${thinking ? 'busy' : over ? 'over' : 'ready'}`} aria-hidden="true" />
          {status}
          {thinking && <Thinking label="Engine thinking" />}
        </p>
        {tc && (
          <div className="clocks" aria-label="Clocks">
            <span className={state.turn === 'Black' && !over ? 'on' : ''}>
              <span className="clock-side">Engine</span> {clock(tc.blackTimeMs)}
            </span>
            <span className={state.turn === 'White' && !over ? 'on' : ''}>
              <span className="clock-side">You</span> {clock(tc.whiteTimeMs)}
            </span>
          </div>
        )}
      </header>

      <div className="board-wrap">
        <Board
          board={live ? toMatrix(state.board) : shown.board}
          highlight={live ? moveSquares(state.lastMove) : shown.squares}
          selected={live ? selected : null}
          targets={live ? targets : []}
          onSelect={live && playable ? touch : null}
          moveKey={live ? state.moveHistory.length : null}
        />
        {!live && (
          <div className="history-banner">
            <span>Viewing the position after move {Math.ceil(viewing / 2)}</span>
            <button className="btn btn-solid btn-sm" onClick={() => onView(null)}>
              Back to the game
            </button>
          </div>
        )}
      </div>

      {error && <p className="error">{error}</p>}

      <div className="play-bar">
        <span className="play-hint">
          {live
            ? playable
              ? 'Click a piece, then a highlighted square.'
              : over
                ? 'Game over — start another below.'
                : 'Hold on while the engine replies.'
            : 'Click any move to look back; the game waits for you.'}
        </span>
        <span className="taken">
          {state.playerScore > 0 && <>You +{state.playerScore}</>}
          {state.playerScore > 0 && state.opponentScore > 0 && ' · '}
          {state.opponentScore > 0 && <>Engine +{state.opponentScore}</>}
        </span>
      </div>

      <div className="new-game">
        <span className="label new-game-label">New game</span>
        {TIME_CONTROLS.map((t) => (
          <button key={t.label} className="chip" onClick={() => restart(t.ms, t.inc)} disabled={restarting}>
            {t.label}
          </button>
        ))}
      </div>

      <Scoresheet moves={frames.moves} viewing={viewing} onView={onView} />
    </div>
  );
}
