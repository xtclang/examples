import { useEffect, useState } from 'react';
import './Room.css';
import GameView, { GameSkeleton } from './GameView.jsx';
import { ConfirmModal, GameOverModal } from './Modals.jsx';
import { PiecePair } from './Piece.jsx';
import { Thinking, usePersistentState } from './ui.jsx';
import { formatClock, TIME_CONTROLS } from '../lib/clock.js';

/** The address a friend opens to join this room. */
const inviteLink = (code) => `${window.location.origin}${window.location.pathname}?room=${code}`;

/** Nobody is in a room yet: open one, or join a friend's with its code. */
function Lobby({ room, joinCode }) {
  const [name, setName] = usePersistentState('draughts-name', '');
  const [code, setCode] = useState((joinCode ?? '').toUpperCase());
  const [timeLabel, setTimeLabel] = usePersistentState('draughts-room-clock', TIME_CONTROLS[0].label);
  const timeControl = TIME_CONTROLS.find((t) => t.label === timeLabel) ?? TIME_CONTROLS[0];

  const create = () => room.enter('', name.trim(), timeControl);
  const join = (e) => {
    e.preventDefault();
    if (code.trim()) room.enter(code.trim(), name.trim());
  };

  return (
    <div className="lobby">
      <div className="lobby-card">
        <div className="modal-head">
          <PiecePair size={34} />
          <h2>Play a friend</h2>
        </div>
        <p className="lobby-lead">Open a room and send the code or link, or join a friend&apos;s room.</p>

        <label className="field">
          <span className="label">Your nickname</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={20}
            placeholder="Nickname"
            autoComplete="nickname"
          />
        </label>

        <fieldset className="choice">
          <legend className="label">Clock</legend>
          <div className="chips" role="radiogroup" aria-label="Clock">
            {TIME_CONTROLS.map((t) => (
              <button
                key={t.label}
                type="button"
                role="radio"
                aria-checked={t.label === timeControl.label}
                className={`chip${t.label === timeControl.label ? ' on' : ''}`}
                onClick={() => setTimeLabel(t.label)}
              >
                {t.label}
              </button>
            ))}
          </div>
        </fieldset>

        <button className="btn btn-solid btn-wide-center" onClick={create} disabled={room.entering}>
          Create a room
        </button>
        <p className="lobby-note">
          You play Black and move first.
          {timeControl.ms > 0 && ' Each player has a bank of time that runs down only on their turn.'}
        </p>

        <div className="lobby-or" role="separator">
          <span>or join with a code</span>
        </div>

        <form className="lobby-join" onSubmit={join}>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            maxLength={6}
            placeholder="ROOM CODE"
            aria-label="Room code"
            autoComplete="off"
            spellCheck={false}
          />
          <button className="btn btn-solid" type="submit" disabled={room.entering || !code.trim()}>
            Join
          </button>
        </form>

        {room.error && <p className="error">{room.error}</p>}
        <p className="privacy">
          Use a nickname, not your real name. It is saved on this server and shown on today&apos;s public
          scoreboard when a game ends.
        </p>
      </div>
    </div>
  );
}

/** The room is open and the creator is waiting for a friend to arrive. */
function Waiting({ room }) {
  const { state } = room;
  const [copied, setCopied] = useState(false);
  const link = inviteLink(state.roomCode);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(link);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      window.prompt('Copy this link', link);
    }
  };

  return (
    <div className="lobby">
      <div className="lobby-card lobby-waiting">
        <div className="modal-head">
          <PiecePair size={34} />
          <h2>Room open</h2>
        </div>
        <p className="lobby-lead">Send this code to your friend, or copy the link.</p>
        <p className="room-code" aria-label={`Room code ${state.roomCode}`}>
          {state.roomCode}
        </p>
        <div className="room-actions">
          <button className="btn btn-solid" onClick={copy}>
            {copied ? 'Link copied' : 'Copy invite link'}
          </button>
          <button className="btn" onClick={room.leave} disabled={room.leaving}>
            Close room
          </button>
        </div>
        {state.timed && (
          <p className="lobby-note">
            Clock: {formatClock(state.blackMs)} each
            {state.incrementMs > 0 && `, +${state.incrementMs / 1000} s a move`}
          </p>
        )}
        <p className="lobby-waiting-note">
          Waiting for {state.blackName === 'Black' ? 'a friend' : 'your friend'} to join <Thinking label="Waiting" />
        </p>
      </div>
    </div>
  );
}

/** A room with both players seated. */
function Table({ room }) {
  const { state, playable } = room;
  const [dismissed, setDismissed] = useState(false);
  const [confirming, setConfirming] = useState(false);

  const over = state.status !== 'Ongoing';
  useEffect(() => setDismissed(false), [state.status, state.history.length === 0]);

  const you = state.color; // 'Black' | 'White'
  const opponent = you === 'Black' ? state.whiteName : state.blackName;
  const leave = () => (over ? room.leave() : setConfirming(true));

  const hint = over
    ? state.opponentLeft
      ? `${opponent} has left the room.`
      : 'Game over — play again with a rematch.'
    : state.yourTurn
      ? undefined
      : `Waiting for ${opponent} to move.`;

  return (
    <div className="game-root">
      {over && !dismissed && !confirming && (
        <GameOverModal status={state.status} message={state.message} onDismiss={() => setDismissed(true)}>
          <button className="btn" onClick={() => setDismissed(true)}>
            Review the board
          </button>
          <button className="btn" onClick={room.leave} disabled={room.leaving}>
            Leave room
          </button>
          <button
            className="btn btn-solid"
            onClick={room.rematch}
            disabled={room.rematching || state.opponentLeft}
            title={state.opponentLeft ? `${opponent} has left` : undefined}
          >
            Rematch
          </button>
        </GameOverModal>
      )}
      {confirming && (
        <ConfirmModal
          title="Leave the game?"
          message={`The game is still going. If you leave, ${opponent} wins.`}
          confirm="Leave and forfeit"
          busy={room.leaving}
          onCancel={() => setConfirming(false)}
          onConfirm={room.leave}
        />
      )}

      <GameView
        state={state}
        selection={room.selection}
        playable={playable}
        flipped={you === 'White'}
        you={you}
        error={room.error}
        hint={hint}
        actions={
          <div className="room-head-actions">
            <span className="room-tag" title="Room code">{state.roomCode}</span>
            <button className="btn btn-sm" onClick={leave} disabled={room.leaving}>
              Leave
            </button>
          </div>
        }
      />
    </div>
  );
}

/** The Room page: the lobby, then the waiting screen, then the game. */
export default function Room({ room, joinCode }) {
  const { seat, state, gone, forget } = room;

  // A room that has since been closed is forgotten, so the lobby comes back.
  useEffect(() => {
    if (gone) forget();
  }, [gone, forget]);

  if (!seat) return <Lobby room={room} joinCode={joinCode} />;
  if (!state) return room.error ? <p className="error">{room.error}</p> : <GameSkeleton />;
  if (state.waiting) return <Waiting room={room} />;
  return <Table room={room} />;
}
