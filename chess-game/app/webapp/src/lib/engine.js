import { useEffect, useMemo, useState } from 'react';
import { analysePosition } from '../api.js';

/** A mate score shown on the evaluation scale, in pawns. */
const MATE_PAWNS = 12;

/**
 * Turns one engine reply into a single number on White's scale, so that mates and ordinary
 * evaluations can share an axis. `turn` is the side to move in the analysed position, which is
 * whose point of view the `mate` distance is written from.
 */
export function toWhitePawns({ evaluation, mate }, turn) {
  const side = turn === 'w' ? 1 : -1;
  if (mate !== null && mate !== undefined) {
    const n = Number(mate);
    if (Number.isFinite(n) && n !== 0) return side * Math.sign(n) * MATE_PAWNS;
  }
  const cp = Number(evaluation);
  return Number.isFinite(cp) ? cp : null;
}

const IDLE = {
  points: [], done: 0, total: 0, failed: 0, phase: 'idle', error: null, secondsLeft: 0,
};

/**
 * Minimum gap between requests. The engine is a free service behind a rate limiter: measured
 * against it, one request every 1.5s runs clean, while 0.9s draws HTTP 429 on roughly half.
 * So the pass is deliberately serial and paced rather than parallel and retried.
 */
const MIN_INTERVAL_MS = 1500;

/** Waits before a second and third attempt at a position the limiter turned away. */
const BACKOFF_MS = [3000, 8000];

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * The order to evaluate positions in: both ends first, then repeatedly the midpoint of the
 * widest remaining gap. The curve takes its rough shape within a few seconds and sharpens as
 * the pass goes on, instead of creeping along the first few moves.
 */
export function refinementOrder(n) {
  if (n <= 2) return [...Array(n).keys()];
  const order = [0, n - 1];
  const seen = new Set(order);
  const queue = [[0, n - 1]];
  while (queue.length) {
    const [lo, hi] = queue.shift();
    const mid = (lo + hi) >> 1;
    if (mid > lo && mid < hi && !seen.has(mid)) {
      seen.add(mid);
      order.push(mid);
      queue.push([lo, mid], [mid, hi]);
    }
  }
  for (let i = 0; i < n; i++) if (!seen.has(i)) order.push(i);
  return order;
}

/**
 * Asks the engine to evaluate every position of a game, one at a time.
 *
 * One request per position is the only way to get real engine numbers, and the free endpoint
 * will not take them any faster than this, so the results stream in: the graphs fill as the
 * answers arrive. Positions the engine never answers stay null and the charts skip them.
 *
 * @param positions  one entry per position, `{ fen, turn }`
 */
export function useEngineCurve(positions, { depth = 11, enabled = true } = {}) {
  const [state, setState] = useState(IDLE);

  useEffect(() => {
    if (!enabled || positions.length === 0) {
      setState({ ...IDLE, total: positions.length });
      return;
    }

    let cancelled = false;
    const total = positions.length;
    const points = new Array(total).fill(null);
    let done = 0;
    let failed = 0;

    const publish = (phase) =>
      setState({
        points: [...points],
        done,
        failed,
        total,
        phase,
        error: phase === 'unavailable' ? 'Engine unreachable' : null,
        secondsLeft: Math.round(((total - done) * MIN_INTERVAL_MS) / 1000),
      });

    publish('running');

    (async () => {
      for (const index of refinementOrder(total)) {
        if (cancelled) return;

        for (let attempt = 0; attempt <= BACKOFF_MS.length; attempt++) {
          if (cancelled) return;
          try {
            const reply = await analysePosition(positions[index].fen, depth);
            points[index] = {
              pawns: toWhitePawns(reply, positions[index].turn),
              mate: reply.mate === null ? null : Number(reply.mate),
              best: reply.bestmove ?? null,
              line: reply.continuation ?? null,
            };
            break;
          } catch {
            if (attempt === BACKOFF_MS.length) failed++;
            else await wait(BACKOFF_MS[attempt]);
          }
        }

        done++;
        if (cancelled) return;
        publish('running');
        if (done < total) await wait(MIN_INTERVAL_MS);
      }

      if (!cancelled) publish(failed === total ? 'unavailable' : 'done');
    })();

    return () => {
      cancelled = true;
    };
  }, [positions, depth, enabled]);

  return state;
}

/**
 * Ordinary least squares of `y` on `x` over the pairs where both are present:
 *
 *     y ≈ a + b·x
 *
 * Used to calibrate the local value function against the engine's own evaluations, which says
 * how much of the engine's judgement the simple linear model actually captures.
 */
export function leastSquares(pairs) {
  const rows = pairs.filter(([x, y]) => Number.isFinite(x) && Number.isFinite(y));
  const n = rows.length;
  if (n < 3) return null;

  const mean = (f) => rows.reduce((acc, r) => acc + f(r), 0) / n;
  const mx = mean(([x]) => x);
  const my = mean(([, y]) => y);
  let sxx = 0;
  let syy = 0;
  let sxy = 0;
  for (const [x, y] of rows) {
    sxx += (x - mx) ** 2;
    syy += (y - my) ** 2;
    sxy += (x - mx) * (y - my);
  }
  if (sxx === 0 || syy === 0) return null;

  const slope = sxy / sxx;
  const intercept = my - slope * mx;
  const r = sxy / Math.sqrt(sxx * syy);
  const rmse = Math.sqrt(
    rows.reduce((acc, [x, y]) => acc + (y - (intercept + slope * x)) ** 2, 0) / n
  );
  return { n, slope, intercept, r, r2: r * r, rmse };
}

/** Memoises the `{ fen, turn }` list the engine pass walks. */
export function usePositionList(fens) {
  return useMemo(() => fens ?? [], [fens]);
}
