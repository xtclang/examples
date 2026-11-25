import { useEffect, useRef, useState } from 'react';
import './Play.css';
import Board from './Board.jsx';
import { moveSquares, toMatrix } from '../lib/play.js';
import { Segmented, Skeleton, Thinking } from './ui.jsx';

const TIME_CONTROLS = [
  { label: 'No clock', ms: 0, inc: 0 },
  { label: '5 + 0', ms: 5 * 60_000, inc: 0 },
  { label: '10 + 5', ms: 10 * 60_000, inc: 5_000 },
];
const TIME_OPTIONS = TIME_CONTROLS.map((t) => ({ value: t.label, label: t.label }));
const AI_DIFFICULTIES = [
  { value: 'beginner', label: 'Beginner' },
  { value: 'casual', label: 'Casual' },
  { value: 'strong', label: 'Strong' },
  { value: 'expert', label: 'Expert' },
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

/** A prominent, non-blocking alert for "Check!" -- urgent enough to notice, not a dialog that
 *  stops play. */
function CheckAlert({ onYou }) {
  return (
    <p className="check-alert" role="alert">
      <span className="status-dot busy" aria-hidden="true" />
      Check{onYou ? ' — your king' : ''}!
    </p>
  );
}

/** New game + time control, tucked behind one button instead of sitting in the main flow. */
function GameMenu({ options, value, onChange, difficulty, onDifficultyChange, onNewGame, busy }) {
  const ref = useRef(null);
  return (
    <details className="game-menu" ref={ref}>
      <summary className="btn btn-sm">
        Game
        <svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true">
          <path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </summary>
      <div className="game-menu-body">
        <Segmented label="Time control" value={value} onChange={onChange} options={options} size="sm" />
        <Segmented
          label="AI difficulty"
          value={difficulty}
          onChange={onDifficultyChange}
          options={AI_DIFFICULTIES}
          size="sm"
        />
        <button
          className="btn btn-solid btn-sm"
          onClick={() => {
            ref.current?.removeAttribute('open');
            onNewGame();
          }}
          disabled={busy}
        >
          New game
        </button>
      </div>
    </details>
  );
}

/** The game-state alert: checkmate, stalemate, draw or timeout, with a way to play again. */
function GameOverModal({ message, onRestart, onDismiss, restarting }) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onDismiss}>
      <div
        className="modal game-over-modal"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="game-over-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="game-over-title">Game over</h2>
        <p>{message}</p>
        <div className="modal-actions">
          <button className="btn" onClick={onDismiss}>
            Review the board
          </button>
          {TIME_CONTROLS.map((t) => (
            <button
              key={t.label}
              className="btn btn-solid"
              onClick={() => onRestart(t.ms, t.inc)}
              disabled={restarting}
            >
              Rematch · {t.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function Play({ play, viewing, onView }) {
  const { state, frames, selected, targets, error, thinking, playable, touch, restart, restarting } = play;

  const [dismissed, setDismissed] = useState(false);
  const [nextLabel, setNextLabel] = useState(TIME_CONTROLS[0].label);
  const [nextDifficulty, setNextDifficulty] = useState('strong');
  const lastStatus = useRef(state?.status);
  useEffect(() => {
    if (state?.status !== lastStatus.current) setDismissed(false);
    lastStatus.current = state?.status;
  }, [state?.status]);
  useEffect(() => {
    if (state?.difficulty) setNextDifficulty(state.difficulty);
  }, [state?.difficulty]);

  if (!state) return error ? <p className="error">{error}</p> : <PlaySkeleton />;

  const live = viewing === null;
  const shown = live ? null : frames.positions[viewing];
  const tc = state.timeControl;
  const over = state.status !== 'Ongoing';
  const inCheck = live && !over && state.inCheck;

  const status = over
    ? state.message
    : thinking
      ? 'The engine is thinking'
      : playable
        ? 'Your move'
        : 'Waiting';

  return (
    <div className="play">
      {over && !dismissed && (
        <GameOverModal
          message={state.message}
          onRestart={(ms, inc) => {
            setDismissed(true);
            restart(ms, inc);
          }}
          onDismiss={() => setDismissed(true)}
          restarting={restarting}
        />
      )}

      <header className="play-head">
        <p className="play-status" aria-live="polite">
          <span className={`status-dot ${thinking ? 'busy' : over ? 'over' : 'ready'}`} aria-hidden="true" />
          {status}
          {thinking && <Thinking label="Engine thinking" />}
        </p>
        <div className="play-head-right">
          {tc && (
            <div className="clocks" aria-label="Clocks">
              <span className={state.turn === 'Black' && !over ? 'on' : ''}>
                <span className="clock-side">Engine · {AI_DIFFICULTIES.find((level) => level.value === state.difficulty)?.label ?? 'Strong'}</span> {clock(tc.blackTimeMs)}
              </span>
              <span className={state.turn === 'White' && !over ? 'on' : ''}>
                <span className="clock-side">You</span> {clock(tc.whiteTimeMs)}
              </span>
            </div>
          )}
          <GameMenu
            options={TIME_OPTIONS}
            value={nextLabel}
            onChange={setNextLabel}
            difficulty={nextDifficulty}
            onDifficultyChange={setNextDifficulty}
            busy={restarting}
            onNewGame={() => {
              const t = TIME_CONTROLS.find((tc) => tc.label === nextLabel) ?? TIME_CONTROLS[0];
              restart(t.ms, t.inc, nextDifficulty);
            }}
          />
        </div>
      </header>

      {inCheck && <CheckAlert onYou={state.turn === 'White'} />}

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

      <p className="play-hint">
        {live
          ? playable
            ? 'Click a piece, then a highlighted square.'
            : over
              ? 'Game over — start another from the Game menu above.'
              : 'Hold on while the engine replies.'
          : 'Click any move to look back; the game waits for you.'}
      </p>

      <Scoresheet moves={frames.moves} viewing={viewing} onView={onView} />

      <div className="play-bar">
        <span className="taken">
          {state.playerScore > 0 && <>You +{state.playerScore}</>}
          {state.playerScore > 0 && state.opponentScore > 0 && ' · '}
          {state.opponentScore > 0 && <>Engine +{state.opponentScore}</>}
        </span>
      </div>
    </div>
  );
}
