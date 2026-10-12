import Board from './Board.jsx';
import { moveSquares, toMatrix } from '../lib/play.js';

const GLYPHS = { k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟' };

/** Mid-game the clock is optional; these are the choices offered when starting a new one. */
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

/** The moves so far, as two columns of a scoresheet. */
function Scoresheet({ history }) {
  if (!history?.length) return null;
  const rows = [];
  for (let i = 0; i < history.length; i += 2) {
    rows.push([Math.floor(i / 2) + 1, history[i], history[i + 1]]);
  }
  return (
    <ol className="scoresheet">
      {rows.map(([no, white, black]) => (
        <li key={no}>
          <span className="no">{no}.</span>
          <span>{white?.notation ?? ''}</span>
          <span>{black?.notation ?? ''}</span>
        </li>
      ))}
    </ol>
  );
}

export default function Play({ play }) {
  const { state, selected, targets, error, busy, playable, touch, restart } = play;

  if (!state) {
    return <p className="empty">{error || 'Starting a game…'}</p>;
  }

  const board = toMatrix(state.board);
  const tc = state.timeControl;
  const over = state.status !== 'Ongoing';

  return (
    <div className="play">
      <header className="play-head">
        <h2 className="board-title">
          You are White · {state.message}
        </h2>
        {tc && (
          <div className="clocks">
            <span className={state.turn === 'Black' && !over ? 'on' : ''}>
              Black {clock(tc.blackTimeMs)}
            </span>
            <span className={state.turn === 'White' && !over ? 'on' : ''}>
              White {clock(tc.whiteTimeMs)}
            </span>
          </div>
        )}
      </header>

      <Board
        board={board}
        highlight={moveSquares(state.lastMove)}
        selected={selected}
        targets={targets}
        onSelect={playable && !busy ? touch : null}
      />

      <div className="play-bar">
        <span className={state.opponentPending ? 'thinking' : ''}>
          {over
            ? state.status
            : state.opponentPending
              ? 'The engine is thinking…'
              : playable
                ? 'Your move — click a piece, then where it goes'
                : 'Waiting…'}
        </span>
        <span className="taken">
          {state.playerScore > 0 && <>you +{state.playerScore}</>}
          {state.opponentScore > 0 && <> · engine +{state.opponentScore}</>}
        </span>
      </div>

      {error && <p className="error">{error}</p>}

      <div className="new-game">
        <span>New game:</span>
        {TIME_CONTROLS.map((t) => (
          <button key={t.label} onClick={() => restart(t.ms, t.inc)} disabled={busy}>
            {t.label}
          </button>
        ))}
      </div>

      <Scoresheet history={state.moveHistory} />
    </div>
  );
}
