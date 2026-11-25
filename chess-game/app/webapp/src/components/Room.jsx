import { useEffect, useRef, useState } from 'react';
import Board from './Board.jsx';
import { moveSquares, toMatrix } from '../lib/play.js';
import { Segmented, Skeleton, Thinking } from './ui.jsx';
import './Play.css';
import './Room.css';

const TIME_CONTROLS = [
  { label: 'No clock', ms: 0, inc: 0 },
  { label: '5 + 0', ms: 5 * 60_000, inc: 0 },
  { label: '10 + 5', ms: 10 * 60_000, inc: 5_000 },
];
const TIME_OPTIONS = TIME_CONTROLS.map((t) => ({ value: t.label, label: t.label }));

const clock = (ms) => {
  if (!Number.isFinite(ms)) return '—';
  const total = Math.max(0, Math.round(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

const inviteUrl = (roomCode) => `${location.origin}${location.pathname}?room=${roomCode}`;

/** The room code and a link a friend can click straight into the seat across the board. */
function InviteCard({ roomCode }) {
  const [copied, setCopied] = useState(false);
  const timer = useRef(0);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(inviteUrl(roomCode));
      setCopied(true);
      clearTimeout(timer.current);
      timer.current = setTimeout(() => setCopied(false), 1800);
    } catch {
      // Clipboard permission denied or unavailable: the code itself is still visible to copy.
    }
  };

  return (
    <div className="room-code-card">
      <span className="label">Room code</span>
      <span className="room-code-value">{roomCode}</span>
      <button className="btn btn-primary room-copy" onClick={copy}>
        {copied ? 'Copied!' : 'Copy invite link'}
      </button>
      <p className="room-hint">Anyone with this link joins straight into the seat across from you.</p>
    </div>
  );
}

function RoomSkeleton() {
  return (
    <div className="room">
      <Skeleton width="16rem" height="1.4rem" />
      <div className="board board-skeleton">
        <Skeleton width="100%" height="100%" radius={8} />
      </div>
    </div>
  );
}

/** Create a room or join one by code -- the entry point when this browser has no seat yet. */
function RoomEntry({ joinCode, create, creating, join, joining, error }) {
  const [code, setCode] = useState(joinCode ?? '');
  const [label, setLabel] = useState(TIME_CONTROLS[0].label);

  useEffect(() => {
    if (joinCode) setCode(joinCode);
  }, [joinCode]);

  const submitJoin = (e) => {
    e.preventDefault();
    if (code.trim()) join(code);
  };

  return (
    <div className="room room-entry">
      <div className="room-cards">
        <div className="panel room-card">
          <h2 className="room-card-title">Start a room</h2>
          <p>Play a friend over the board. You play White; whoever joins your room plays Black.</p>
          <Segmented label="Time control" value={label} onChange={setLabel} options={TIME_OPTIONS} size="sm" />
          <button
            className="btn btn-primary"
            disabled={creating}
            onClick={() => {
              const t = TIME_CONTROLS.find((tc) => tc.label === label) ?? TIME_CONTROLS[0];
              create(t.ms, t.inc);
            }}
          >
            {creating ? 'Creating…' : 'Create room'}
          </button>
        </div>

        <div className="panel room-card">
          <h2 className="section-toggle-like">Join a room</h2>
          <p>Have a code or a link from a friend? Enter it here.</p>
          <form className="room-join-form" onSubmit={submitJoin}>
            <input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="ROOM CODE"
              aria-label="Room code"
              maxLength={6}
            />
            <button className="btn btn-primary" type="submit" disabled={joining || !code.trim()}>
              {joining ? 'Joining…' : 'Join'}
            </button>
          </form>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
    </div>
  );
}

export default function Room({ online, joinCode }) {
  const {
    room, state, frames, loading, error, playable,
    selected, targets, touch, create, creating, join, joining,
    leave, leaving, restart, restarting,
  } = online;

  const attempted = useRef(false);
  useEffect(() => {
    if (joinCode && !room && !attempted.current) {
      attempted.current = true;
      join(joinCode);
    }
  }, [joinCode, room, join]);

  if (!room) {
    return (
      <RoomEntry
        joinCode={joinCode}
        create={create}
        creating={creating}
        join={join}
        joining={joining}
        error={error}
      />
    );
  }

  if (loading || !state) return <RoomSkeleton />;

  if (state.waitingForOpponent) {
    return (
      <div className="room room-waiting">
        <InviteCard roomCode={state.roomCode} />
        <button className="btn" onClick={leave} disabled={leaving}>
          Cancel room
        </button>
      </div>
    );
  }

  const over = state.status !== 'Ongoing';
  const youAreWhite = state.playerColor === 'White';
  const tc = state.timeControl;

  const status = state.opponentLeft
    ? 'Your opponent left the game.'
    : over
      ? state.message
      : playable
        ? 'Your move'
        : state.message || 'Waiting for your opponent';

  return (
    <div className="room room-playing">
      <header className="play-head">
        <p className="play-status" aria-live="polite">
          <span className={`status-dot ${over ? 'over' : playable ? 'ready' : 'busy'}`} aria-hidden="true" />
          {status}
          {!over && !playable && !state.opponentLeft && <Thinking label="Waiting for opponent" />}
        </p>
        <div className="play-head-right">
          {tc && (
            <div className="clocks" aria-label="Clocks">
              <span className={state.turn === (youAreWhite ? 'Black' : 'White') && !over ? 'on' : ''}>
                <span className="clock-side">Opponent</span> {clock(youAreWhite ? tc.blackTimeMs : tc.whiteTimeMs)}
              </span>
              <span className={state.turn === (youAreWhite ? 'White' : 'Black') && !over ? 'on' : ''}>
                <span className="clock-side">You</span> {clock(youAreWhite ? tc.whiteTimeMs : tc.blackTimeMs)}
              </span>
            </div>
          )}
          <button className="btn btn-sm" onClick={leave} disabled={leaving}>
            Leave
          </button>
        </div>
      </header>

      <div className="room-code-chip">
        <span className="label">Room {state.roomCode}</span>
      </div>

      <div className="board-wrap">
        <Board
          board={toMatrix(state.board)}
          highlight={moveSquares(state.lastMove)}
          selected={selected}
          targets={targets}
          onSelect={playable ? touch : null}
          flipped={!youAreWhite}
          moveKey={state.moveHistory.length}
        />
      </div>

      {error && <p className="error">{error}</p>}

      <p className="play-hint">
        {state.opponentLeft
          ? 'Start a new room to play again.'
          : playable
            ? 'Click a piece, then a highlighted square.'
            : over
              ? state.message
              : 'Hold on for your opponent’s move.'}
      </p>

      {over && !state.opponentLeft && (
        <button className="btn btn-solid" onClick={restart} disabled={restarting}>
          {restarting ? 'Starting…' : 'Rematch'}
        </button>
      )}

      <div className="play-bar">
        <span className="taken">
          {state.playerScore > 0 && <>You +{state.playerScore}</>}
          {state.playerScore > 0 && state.opponentScore > 0 && ' · '}
          {state.opponentScore > 0 && <>Opponent +{state.opponentScore}</>}
        </span>
      </div>
    </div>
  );
}
