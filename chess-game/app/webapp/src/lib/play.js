import { useCallback, useEffect, useRef, useState } from 'react';
import { getGameState, getValidMoves, playMove, resetGame } from '../api.js';

const SESSION_KEY = 'chess-session';

/**
 * The id this browser plays under. The backend keeps one game per session id, so it is kept in
 * local storage: reload the page and the game is still there.
 */
export function ensureSession() {
  const fresh = () => `web-${Math.random().toString(36).slice(2, 10)}`;
  try {
    let id = localStorage.getItem(SESSION_KEY);
    if (!id || !/^[A-Za-z0-9_-]{3,40}$/.test(id)) {
      id = fresh();
      localStorage.setItem(SESSION_KEY, id);
    }
    return id;
  } catch {
    // Private windows and blocked site data: play this session without remembering it.
    return fresh();
  }
}

/** The backend sends 8 rows, rank 8 first, upper case for White. The board wants a matrix. */
export function toMatrix(rows = []) {
  return rows.map((row) =>
    [...row].map((ch) =>
      ch === '.' ? null : { type: ch.toLowerCase(), color: ch === ch.toUpperCase() ? 'w' : 'b' }
    )
  );
}

/** "e2e4" → ["e2", "e4"], for highlighting the move just played. */
export function moveSquares(lastMove) {
  return typeof lastMove === 'string' && lastMove.length >= 4
    ? [lastMove.slice(0, 2), lastMove.slice(2, 4)]
    : [];
}

const POLL_MS = 1200;

/**
 * Plays one game against the computer.
 *
 * The opponent's reply is not pushed: the server applies it on the first request that arrives
 * after its thinking delay, so while `opponentPending` is set this polls until the move lands.
 */
export function usePlay() {
  const [sessionId] = useState(ensureSession);
  const [state, setState] = useState(null);
  const [selected, setSelected] = useState(null);
  const [targets, setTargets] = useState([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const live = useRef(true);

  useEffect(() => {
    live.current = true;
    return () => {
      live.current = false;
    };
  }, []);

  const apply = useCallback((next) => {
    if (!live.current) return;
    setState(next);
    setSelected(null);
    setTargets([]);
  }, []);

  const run = useCallback(
    async (fn) => {
      setBusy(true);
      try {
        apply(await fn());
        setError('');
      } catch (e) {
        if (live.current) setError(e.message);
      } finally {
        if (live.current) setBusy(false);
      }
    },
    [apply]
  );

  // Load the game this session left off at.
  useEffect(() => {
    run(() => getGameState(sessionId));
  }, [sessionId, run]);

  // While the computer is thinking, ask again until its move appears.
  useEffect(() => {
    if (!state?.opponentPending) return;
    const timer = setTimeout(async () => {
      try {
        const next = await getGameState(sessionId);
        if (live.current) setState(next);
      } catch {
        // A failed poll is not worth reporting; the next one will tell the same story.
      }
    }, POLL_MS);
    return () => clearTimeout(timer);
  }, [state, sessionId]);

  const playable = state?.status === 'Ongoing' && state?.turn === 'White' && !state?.opponentPending;

  /** Click a square: pick up a piece, put it down, or switch to another piece. */
  const touch = useCallback(
    async (name) => {
      if (!playable || busy) return;

      if (selected === name) {
        setSelected(null);
        setTargets([]);
        return;
      }

      if (selected && targets.includes(name)) {
        const from = selected;
        setSelected(null);
        setTargets([]);
        await run(() => playMove(sessionId, from, name));
        return;
      }

      try {
        const reply = await getValidMoves(sessionId, name);
        if (!live.current) return;
        if (reply.success && reply.validMoves?.length) {
          setSelected(name);
          setTargets(reply.validMoves);
          setError('');
        } else {
          setSelected(null);
          setTargets([]);
        }
      } catch (e) {
        if (live.current) setError(e.message);
      }
    },
    [playable, busy, selected, targets, sessionId, run]
  );

  const restart = useCallback(
    (timeControlMs = 0, incrementMs = 0) =>
      run(() => resetGame(sessionId, timeControlMs, incrementMs)),
    [run, sessionId]
  );

  return { sessionId, state, selected, targets, error, busy, playable, touch, restart };
}
