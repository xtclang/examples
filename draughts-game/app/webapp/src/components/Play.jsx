import { useEffect, useRef, useState } from 'react';
import './Play.css';
import Board from './Board.jsx';
import { boardAlong, moveSquares, toMatrix } from '../lib/play.js';
import { Skeleton, usePersistentState } from './ui.jsx';

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

/** One player: a disc in their colour, their nickname, and how many pieces they have left. */
function PlayerTag({ color, name, pieces, active }) {
  return (
    <div className={`player${active ? ' on' : ''}`} aria-current={active ? 'true' : undefined}>
      <span className={`disc disc-${color}`} aria-hidden="true" />
      <span className="player-name">{name}</span>
      <span className="player-side">{color === 'b' ? 'Black · moves first' : 'White'}</span>
      <span className="player-count">{pieces}</span>
    </div>
  );
}

/** Who is playing. Asked before the first game, and again from "New game". */
function NewGameModal({ initial, onStart, onCancel, busy }) {
  const [black, setBlack] = useState(initial.black);
  const [white, setWhite] = useState(initial.white);
  const first = useRef(null);
  useEffect(() => first.current?.focus(), []);

  const submit = (e) => {
    e.preventDefault();
    onStart(black.trim(), white.trim());
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onCancel}>
      <form
        className="modal new-game-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="new-game-title"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h2 id="new-game-title">New game</h2>
        <label className="field">
          <span className="label">Black — moves first</span>
          <input
            ref={first}
            value={black}
            onChange={(e) => setBlack(e.target.value)}
            maxLength={20}
            placeholder="Black"
            autoComplete="nickname"
          />
        </label>
        <label className="field">
          <span className="label">White</span>
          <input
            value={white}
            onChange={(e) => setWhite(e.target.value)}
            maxLength={20}
            placeholder="White"
            autoComplete="off"
          />
        </label>
        <p className="privacy">
          Use nicknames, not real names. They are saved on this server and shown on today&apos;s public
          scoreboard when a game ends. This browser also remembers them for next time.
        </p>
        <div className="modal-actions">
          {onCancel && (
            <button type="button" className="btn" onClick={onCancel}>
              Cancel
            </button>
          )}
          <button type="submit" className="btn btn-solid" disabled={busy}>
            Play
          </button>
        </div>
      </form>
    </div>
  );
}

/** The game-state alert: someone won, or it is a draw, with a way to play again. */
function GameOverModal({ message, onRematch, onNew, onDismiss, busy }) {
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
          <button className="btn" onClick={onNew}>
            New players
          </button>
          <button className="btn btn-solid" onClick={onRematch} disabled={busy}>
            Rematch
          </button>
        </div>
      </div>
    </div>
  );
}

export default function Play({ play }) {
  const { state, error, playable, path, selected, targets, movable, touch, restart, restarting } = play;

  // The nicknames this browser used last, so they are filled in next time.
  const [names, setNames] = usePersistentState('draughts-names', null);
  const [asking, setAsking] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [viewing, setViewing] = useState(null);
  const lastStatus = useRef(state?.status);

  const moveCount = state?.history.length ?? 0;
  const over = state ? state.status !== 'Ongoing' : false;

  useEffect(() => {
    if (state?.status !== lastStatus.current) setDismissed(false);
    lastStatus.current = state?.status;
  }, [state?.status]);
  useEffect(() => setViewing(null), [moveCount]);

  // First visit, nothing played yet: ask who is playing before the first move.
  const [greeted, setGreeted] = useState(false);
  useEffect(() => {
    if (state && !greeted) {
      setGreeted(true);
      if (!names && moveCount === 0) setAsking(true);
    }
  }, [state, greeted, names, moveCount]);

  if (!state) return error ? <p className="error">{error}</p> : <PlaySkeleton />;

  const start = (black, white) => {
    setNames({ black, white });
    setAsking(false);
    setDismissed(true);
    restart(black, white);
  };

  const live = viewing === null;
  const shownBoard = live ? boardAlong(toMatrix(state.board), path) : toMatrix(state.history[viewing - 1].boardAfter.match(/.{8}/g));
  const highlight = live
    ? moveSquares(state.lastMove)
    : moveSquares(state.history[viewing - 1].path);
  const black = state.turn === 'Black';

  const status = over ? state.message : state.message;
  return (
    <div className="play">
      {asking && (
        <NewGameModal
          initial={names ?? { black: '', white: '' }}
          onStart={start}
          onCancel={moveCount === 0 && !names ? null : () => setAsking(false)}
          busy={restarting}
        />
      )}
      {over && !dismissed && !asking && (
        <GameOverModal
          message={state.message}
          busy={restarting}
          onDismiss={() => setDismissed(true)}
          onRematch={() => start(state.blackName, state.whiteName)}
          onNew={() => setAsking(true)}
        />
      )}

      <header className="play-head">
        <p className="play-status" aria-live="polite">
          <span className={`status-dot ${over ? 'over' : 'ready'}`} aria-hidden="true" />
          {status}
        </p>
        <button className="btn btn-solid btn-sm" onClick={() => setAsking(true)}>
          New game
        </button>
      </header>

      <PlayerTag color="w" name={state.whiteName} pieces={state.whitePieces} active={!over && !black} />

      <div className="board-wrap">
        <Board
          board={shownBoard}
          highlight={highlight}
          selected={live ? selected : null}
          targets={live ? targets : []}
          movable={live && playable ? movable : null}
          onSelect={live && playable ? touch : null}
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

      <PlayerTag color="b" name={state.blackName} pieces={state.blackPieces} active={!over && black} />

      {error && <p className="error">{error}</p>}

      <p className="play-hint">
        {!live
          ? 'Click any move to look back; the game waits for you.'
          : over
            ? 'Game over — start another with New game.'
            : path.length > 1
              ? 'Keep jumping: choose the next square.'
              : state.mustCapture
                ? 'A capture is compulsory. The pieces that can capture are ringed.'
                : 'Click a piece, then a highlighted square.'}
      </p>

      <Scoresheet
        history={state.history}
        viewing={viewing}
        onView={(k) => setViewing(k >= moveCount ? null : k)}
      />
    </div>
  );
}
