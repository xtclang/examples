import { useEffect, useRef, useState } from 'react';
import './Play.css';
import Board from './Board.jsx';
import { boardAlong, moveSquares, toMatrix } from '../lib/play.js';
import { Skeleton, Thinking, usePersistentState } from './ui.jsx';

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
function PlayerTag({ color, name, pieces, active, computer, thinking }) {
  return (
    <div className={`player${active ? ' on' : ''}`} aria-current={active ? 'true' : undefined}>
      <span className={`disc disc-${color}`} aria-hidden="true" />
      <span className="player-name">{name}</span>
      <span className="player-side">
        {computer ? 'Computer' : color === 'b' ? 'Black · moves first' : 'White'}
      </span>
      {thinking && <Thinking label="Computer thinking" />}
      <span className="player-count" title="Pieces left">{pieces}</span>
    </div>
  );
}

const LEVELS = [
  { value: 'easy', label: 'Low', note: 'Looks 2 moves ahead and sometimes slips.' },
  { value: 'medium', label: 'Medium', note: 'Looks 4 moves ahead; the odd slip.' },
  { value: 'hard', label: 'High', note: 'Looks up to 7 moves ahead and never slips. It may take a few seconds.' },
];

const DEFAULT_SETUP = { mode: '1', black: '', white: '', level: 'medium' };

/** Who is playing, and against what. Asked before the first game, and again from "New game". */
function NewGameModal({ initial, onStart, onCancel, busy }) {
  const [setup, setSetup] = useState({ ...DEFAULT_SETUP, ...initial });
  const first = useRef(null);
  useEffect(() => first.current?.focus(), []);
  const set = (patch) => setSetup((current) => ({ ...current, ...patch }));
  const vsComputer = setup.mode === '1';

  const submit = (e) => {
    e.preventDefault();
    onStart({ ...setup, black: setup.black.trim(), white: setup.white.trim() });
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

        <fieldset className="choice">
          <legend className="label">Players</legend>
          <div className="chips" role="radiogroup" aria-label="Players">
            {[
              ['1', '1 player'],
              ['2', '2 players'],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                role="radio"
                aria-checked={setup.mode === value}
                className={`chip${setup.mode === value ? ' on' : ''}`}
                onClick={() => set({ mode: value })}
              >
                {label}
              </button>
            ))}
          </div>
        </fieldset>

        <label className="field">
          <span className="label">{vsComputer ? 'Your nickname (Black, moves first)' : 'Black — moves first'}</span>
          <input
            ref={first}
            value={setup.black}
            onChange={(e) => set({ black: e.target.value })}
            maxLength={20}
            placeholder="Black"
            autoComplete="nickname"
          />
        </label>

        {vsComputer ? (
          <fieldset className="choice">
            <legend className="label">Computer strength</legend>
            <div className="chips" role="radiogroup" aria-label="Computer strength">
              {LEVELS.map((level) => (
                <button
                  key={level.value}
                  type="button"
                  role="radio"
                  aria-checked={setup.level === level.value}
                  className={`chip${setup.level === level.value ? ' on' : ''}`}
                  onClick={() => set({ level: level.value })}
                >
                  {level.label}
                </button>
              ))}
            </div>
            <p className="level-note">{LEVELS.find((level) => level.value === setup.level)?.note}</p>
          </fieldset>
        ) : (
          <label className="field">
            <span className="label">White</span>
            <input
              value={setup.white}
              onChange={(e) => set({ white: e.target.value })}
              maxLength={20}
              placeholder="White"
              autoComplete="off"
            />
          </label>
        )}

        <p className="privacy">
          Use nicknames, not real names. They are saved on this server and shown on today&apos;s public
          scoreboard when a game ends. This browser also remembers your choices for next time.
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
  const { state, error, playable, thinking, path, selected, targets, movable, touch, restart, restarting } =
    play;

  // What this browser chose last time, so it is filled in next time.
  const [saved, setSaved] = usePersistentState('draughts-setup', null);
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
      if (!saved && moveCount === 0) setAsking(true);
    }
  }, [state, greeted, saved, moveCount]);

  if (!state) return error ? <p className="error">{error}</p> : <PlaySkeleton />;

  const start = (setup) => {
    setSaved(setup);
    setAsking(false);
    setDismissed(true);
    restart({
      black: setup.black,
      white: setup.white,
      level: setup.mode === '1' ? setup.level : '',
    });
  };
  const vsComputer = state.level !== '';

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
          initial={saved ?? DEFAULT_SETUP}
          onStart={start}
          onCancel={moveCount === 0 && !saved ? null : () => setAsking(false)}
          busy={restarting}
        />
      )}
      {over && !dismissed && !asking && (
        <GameOverModal
          message={state.message}
          busy={restarting}
          onDismiss={() => setDismissed(true)}
          onRematch={() => start(saved ?? { ...DEFAULT_SETUP, mode: vsComputer ? '1' : '2', black: state.blackName, white: state.whiteName, level: state.level || 'medium' })}
          onNew={() => setAsking(true)}
        />
      )}

      <header className="play-head">
        <p className="play-status" aria-live="polite">
          <span className={`status-dot ${over ? 'over' : thinking ? 'busy' : 'ready'}`} aria-hidden="true" />
          {status}
        </p>
        <button className="btn btn-solid btn-sm" onClick={() => setAsking(true)}>
          New game
        </button>
      </header>

      <PlayerTag
        color="w"
        name={state.whiteName}
        pieces={state.whitePieces}
        active={!over && !black}
        computer={vsComputer}
        thinking={thinking}
      />

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
            : thinking
              ? 'The computer is choosing its move.'
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
