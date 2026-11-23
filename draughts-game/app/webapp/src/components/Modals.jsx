import { useEffect, useRef, useState } from 'react';
import { PieceIcon, PiecePair } from './Piece.jsx';

export const LEVELS = [
  { value: 'easy', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'hard', label: 'High' },
];

export const DEFAULT_SETUP = { mode: '1', black: '', white: '', level: 'medium' };

/** Backdrop and card shared by every dialog. A click outside the card dismisses it. */
function Modal({ labelledBy, role = 'dialog', onDismiss, className = '', children, ...rest }) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onDismiss}>
      <div
        className={`modal ${className}`}
        role={role}
        aria-modal="true"
        aria-labelledby={labelledBy}
        onClick={(e) => e.stopPropagation()}
        {...rest}
      >
        {children}
      </div>
    </div>
  );
}

/** Who is playing, and against what. Asked before the first game, and again from "New game". */
export function NewGameModal({ initial, onStart, onCancel, busy }) {
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
    <Modal labelledBy="new-game-title" onDismiss={onCancel} className="new-game-modal">
      <form onSubmit={submit}>
        <div className="modal-head">
          <PiecePair size={34} />
          <h2 id="new-game-title">New game</h2>
        </div>

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
          scoreboard when a game ends.
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
    </Modal>
  );
}

/** Which piece stands for how the game ended: the winner's, wearing a crown; both for a draw. */
function ResultPieces({ status }) {
  if (status === 'BlackWins') return <PieceIcon color="b" king size={64} />;
  if (status === 'WhiteWins') return <PieceIcon color="w" king size={64} />;
  return <PiecePair size={56} />;
}

/** The game-state alert: someone won, or it is a draw, with a way to carry on. */
export function GameOverModal({ status, message, onDismiss, children }) {
  return (
    <Modal labelledBy="game-over-title" role="alertdialog" onDismiss={onDismiss} className="game-over-modal">
      <div className="result-pieces">
        <ResultPieces status={status} />
      </div>
      <h2 id="game-over-title">{status === 'Draw' ? 'Draw' : 'Game over'}</h2>
      <p>{message}</p>
      <div className="modal-actions">{children}</div>
    </Modal>
  );
}

/** A yes/no question, e.g. before leaving a game in progress. */
export function ConfirmModal({ title, message, confirm, onConfirm, onCancel, busy }) {
  return (
    <Modal labelledBy="confirm-title" role="alertdialog" onDismiss={onCancel} className="game-over-modal">
      <div className="result-pieces">
        <PiecePair size={44} />
      </div>
      <h2 id="confirm-title">{title}</h2>
      <p>{message}</p>
      <div className="modal-actions">
        <button className="btn" onClick={onCancel}>
          Stay
        </button>
        <button className="btn btn-solid" onClick={onConfirm} disabled={busy}>
          {confirm}
        </button>
      </div>
    </Modal>
  );
}
