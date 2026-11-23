import { useEffect, useMemo, useState } from 'react';

/** 125000 -> "2:05". */
export function formatClock(ms) {
  const total = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/** A clock is "low" in its last half minute. */
export const LOW_MS = 30_000;

/** Time controls on offer: each player's starting time, and what is added after each of their moves. */
export const TIME_CONTROLS = [
  { label: 'No clock', ms: 0, inc: 0 },
  { label: '3 min', ms: 3 * 60_000, inc: 0 },
  { label: '5 min', ms: 5 * 60_000, inc: 0 },
  { label: '10 min', ms: 10 * 60_000, inc: 0 },
  { label: '5 + 3', ms: 5 * 60_000, inc: 3_000 },
  { label: '10 + 5', ms: 10 * 60_000, inc: 5_000 },
];

/**
 * The clocks of a timed room, counting down between polls.
 *
 * The server sends each player's time as it was when the reply was made, and whether a clock is
 * running. The page keeps the moment each reply arrived and counts down locally from it, so the
 * clock moves smoothly rather than jumping once a poll; the next reply puts it right. When time
 * reaches zero here the next poll finds the game ended, since the server settles it on request.
 *
 * Returns null for a room without clocks.
 */
export function useClocks(state) {
  const arrived = useMemo(() => performance.now(), [state]);
  const [now, setNow] = useState(() => performance.now());
  const running = Boolean(state?.timed && state?.clockRunning);

  useEffect(() => {
    if (!running) return undefined;
    const timer = setInterval(() => setNow(performance.now()), 250);
    return () => clearInterval(timer);
  }, [running, state]);

  if (!state?.timed) return null;
  const elapsed = running ? Math.max(0, now - arrived) : 0;
  const left = (ms, color) => (running && state.turn === color ? Math.max(0, ms - elapsed) : ms);
  return { Black: left(state.blackMs, 'Black'), White: left(state.whiteMs, 'White'), running };
}
