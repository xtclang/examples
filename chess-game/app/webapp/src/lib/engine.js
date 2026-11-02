import { useCallback, useEffect, useMemo } from 'react';
import { useQueries } from '@tanstack/react-query';
import { analysePosition } from '../api.js';

// ---------------------------------------------------------------------------- the scheduler
//
// Every engine number comes from Stockfish Online, one request per position, through the
// server's /api/engine proxy. The free endpoint is rate limited: measured against it, one
// request every 1.5s runs clean, while 0.9s draws HTTP 429 on roughly half. So requests are
// never fired in parallel. They queue here, leave one at a time at that pace, and the position
// the player is looking at always goes first.

/** Minimum gap between two requests leaving for the engine. */
const MIN_INTERVAL_MS = 1500;

/** Waits before a second and third attempt at a position the limiter turned away. */
const BACKOFF_MS = [3000, 8000];

/** Evaluations are kept between visits: a position's evaluation never changes. */
const CACHE_KEY = 'chess-engine-cache-v1';
const CACHE_LIMIT = 3000;

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const cache = loadCache();
let saveTimer = 0;

function loadCache() {
  try {
    const stored = JSON.parse(localStorage.getItem(CACHE_KEY) ?? '[]');
    return new Map(Array.isArray(stored) ? stored : []);
  } catch {
    return new Map();
  }
}

function remember(key, value) {
  cache.delete(key);
  cache.set(key, value);
  while (cache.size > CACHE_LIMIT) cache.delete(cache.keys().next().value);
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify([...cache]));
    } catch {
      // Storage full or blocked: the in-memory cache still serves this visit.
    }
  }, 500);
}

const queue = [];
const inFlight = new Map();
let focus = null;
let pumping = false;
let lastSent = 0;

/** The position the player is looking at jumps the queue. */
export function setEngineFocus(fen) {
  focus = fen ?? null;
}

// The computer opponent asks the same engine for its move, from the server, under the same
// rate limit. If the analysis is mid-stream when the computer thinks, the computer's request is
// the one turned away -- and it falls back to a random move. So while it is the computer's turn
// the queue holds, and once it resumes it leaves a full gap after the computer's request.
let held = false;
let release = null;

export function holdEngine(hold) {
  if (hold === held) return;
  held = hold;
  if (!hold) {
    lastSent = Date.now();
    release?.();
    release = null;
  }
}

/**
 * The engine's reply for one position, from the cache when it has been asked before.
 * Identical requests in flight share one answer.
 */
export function requestEvaluation(fen, depth, { priority = 0, signal } = {}) {
  const key = `${depth}|${fen}`;
  if (cache.has(key)) return Promise.resolve(cache.get(key));
  if (inFlight.has(key)) return inFlight.get(key);

  const promise = new Promise((resolve, reject) => {
    queue.push({ key, fen, depth, priority, signal, resolve, reject });
  }).finally(() => inFlight.delete(key));

  inFlight.set(key, promise);
  pump();
  return promise;
}

function nextJob() {
  for (let i = queue.length - 1; i >= 0; i--) {
    if (queue[i].signal?.aborted) {
      queue[i].reject(new DOMException('Aborted', 'AbortError'));
      queue.splice(i, 1);
    }
  }
  if (!queue.length) return null;
  let best = queue.findIndex((job) => job.fen === focus);
  if (best < 0) {
    best = 0;
    for (let i = 1; i < queue.length; i++) {
      if (queue[i].priority < queue[best].priority) best = i;
    }
  }
  return queue.splice(best, 1)[0];
}

async function pump() {
  if (pumping) return;
  pumping = true;
  try {
    for (let job = nextJob(); job; job = nextJob()) {
      while (held) await new Promise((resolve) => (release = resolve));
      const gap = lastSent + MIN_INTERVAL_MS - Date.now();
      if (gap > 0) await wait(gap);
      if (held) {
        queue.unshift(job);
        continue;
      }

      let reply = null;
      let failure = null;
      for (let attempt = 0; attempt <= BACKOFF_MS.length && !reply; attempt++) {
        if (attempt) await wait(BACKOFF_MS[attempt - 1]);
        while (held) await new Promise((resolve) => (release = resolve));
        if (job.signal?.aborted) break;
        lastSent = Date.now();
        try {
          reply = await analysePosition(job.fen, job.depth);
        } catch (e) {
          failure = e;
        }
      }

      if (reply) {
        remember(job.key, reply);
        job.resolve(reply);
      } else {
        job.reject(failure ?? new DOMException('Aborted', 'AbortError'));
      }
    }
  } finally {
    pumping = false;
  }
}

// ---------------------------------------------------------------------------- reading a reply

/** A mate is shown on the evaluation scale as this many pawns. */
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
  const pawns = Number(evaluation);
  return Number.isFinite(pawns) ? pawns : null;
}

/**
 * The order to evaluate a game's positions in: both ends first, then repeatedly the midpoint of
 * the widest remaining gap. The curve takes its rough shape within seconds and sharpens as the
 * queue drains, instead of creeping along from the first move.
 */
export function refinementOrder(n) {
  if (n <= 2) return [...Array(n).keys()];
  const order = [0, n - 1];
  const seen = new Set(order);
  const pending = [[0, n - 1]];
  while (pending.length) {
    const [lo, hi] = pending.shift();
    const mid = (lo + hi) >> 1;
    if (mid > lo && mid < hi && !seen.has(mid)) {
      seen.add(mid);
      order.push(mid);
      pending.push([lo, mid], [mid, hi]);
    }
  }
  for (let i = 0; i < n; i++) if (!seen.has(i)) order.push(i);
  return order;
}

// ---------------------------------------------------------------------------- the hook

/**
 * Engine evaluations for every position of a game, filled in live.
 *
 * Each position is its own query, keyed by FEN, and an evaluation never goes stale. When a game
 * grows by a move, only the new position is requested; when the same position shows up in
 * another game, it is already known.
 *
 * @param positions  `{ fen, turn }` per position
 * @param current    index of the position on the board, which is evaluated first
 */
export function useEngineEvaluations(positions, { depth = 11, enabled = true, current = null } = {}) {
  const rank = useMemo(() => {
    const ranks = new Array(positions.length);
    refinementOrder(positions.length).forEach((index, order) => (ranks[index] = order + 1));
    return ranks;
  }, [positions.length]);

  const focusFen = current !== null ? positions[current]?.fen : null;
  useEffect(() => setEngineFocus(focusFen), [focusFen]);

  const combine = useCallback(
    (results) => {
      const points = results.map((r, i) =>
        r.data
          ? {
              pawns: toWhitePawns(r.data, positions[i].turn),
              mate: r.data.mate === null ? null : Number(r.data.mate),
              best: r.data.bestmove ?? null,
              line: r.data.continuation ?? null,
            }
          : null
      );
      const done = results.filter((r) => r.isSuccess || r.isError).length;
      const failed = results.filter((r) => r.isError).length;
      return {
        points,
        done,
        failed,
        total: results.length,
        running: enabled && done < results.length,
        unavailable: results.length > 0 && failed === results.length,
        secondsLeft: Math.round(((results.length - done) * MIN_INTERVAL_MS) / 1000),
      };
    },
    [positions, enabled]
  );

  return useQueries({
    queries: positions.map((p, i) => ({
      queryKey: ['engine', depth, p.fen],
      queryFn: ({ signal }) => requestEvaluation(p.fen, depth, { priority: rank[i], signal }),
      enabled,
      staleTime: Infinity,
      gcTime: 60 * 60_000,
      retry: false,
    })),
    combine,
  });
}

/**
 * Least squares of y on x over the pairs where both are present: y ≈ a + b·x.
 *
 * Used to calibrate the local value function against the engine, which says how much of the
 * engine's judgement the simple linear model captures.
 */
export function leastSquares(pairs) {
  const rows = pairs.filter(([x, y]) => Number.isFinite(x) && Number.isFinite(y));
  const n = rows.length;
  if (n < 3) return null;

  const mx = rows.reduce((a, [x]) => a + x, 0) / n;
  const my = rows.reduce((a, [, y]) => a + y, 0) / n;
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
  const rmse = Math.sqrt(rows.reduce((a, [x, y]) => a + (y - (intercept + slope * x)) ** 2, 0) / n);
  return { n, slope, intercept, r, r2: r * r, rmse };
}
