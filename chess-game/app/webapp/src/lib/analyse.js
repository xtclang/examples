import { useEffect, useMemo, useRef, useState } from 'react';
import { Chess } from 'chess.js';
import { entropyBits, evaluate, fitBeta, softmax } from './model.js';

const LOG2 = Math.log(2);
const log2 = (x) => Math.log(x) / LOG2;
const DEFAULT_BETA = 2;

export const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

// ---------------------------------------------------------------------------- games as frames
//
// Both modes reduce to the same shape: the positions of a game, `{ board, fen, turn, squares }`,
// and the moves between them, `{ from, to, promotion, san, color, uci }`. Everything downstream
// -- the board, the engine, the model, the charts -- reads only that.

function frame(game, squares = []) {
  return { board: game.board(), fen: game.fen(), turn: game.turn(), squares };
}

function moveOf(m) {
  return {
    from: m.from,
    to: m.to,
    promotion: m.promotion,
    san: m.san,
    color: m.color,
    uci: `${m.from}${m.to}${m.promotion ?? ''}`,
  };
}

/** A game from chess.com (PGN) or a single position (FEN), as frames. */
export function useGame({ pgn, fen }) {
  return useMemo(() => {
    try {
      if (pgn) {
        const source = new Chess();
        source.loadPgn(pgn);
        const history = source.history({ verbose: true });
        const replay = new Chess(history[0]?.before ?? START_FEN);
        const positions = [frame(replay)];
        for (const m of history) {
          replay.move(m);
          positions.push(frame(replay, [m.from, m.to]));
        }
        return { positions, moves: history.map(moveOf), error: null };
      }
      const game = new Chess(fen ?? START_FEN);
      return { positions: [frame(game)], moves: [], error: null };
    } catch (e) {
      return { positions: [], moves: [], error: e.message };
    }
  }, [pgn, fen]);
}

/**
 * The game being played against the server, as frames.
 *
 * The server keeps the history as from/to squares. Replaying them reconstructs every position
 * exactly -- castling rights and en passant included -- which the board rows alone cannot.
 * Should the server ever accept a move the replay will not, the frames stop there and the
 * server's own FEN stands in for the position on the board.
 */
export function replayHistory(history = [], liveFen = null) {
  const game = new Chess();
  const positions = [frame(game)];
  const moves = [];
  for (const entry of history) {
    const promotion = entry.promotion ? String(entry.promotion).toLowerCase() : undefined;
    let made;
    try {
      made = game.move({ from: entry.fromSquare, to: entry.toSquare, promotion });
    } catch {
      made = null;
    }
    if (!made) break;
    moves.push(moveOf(made));
    positions.push(frame(game, [made.from, made.to]));
  }
  if (liveFen && moves.length < history.length) {
    try {
      positions.push(frame(new Chess(liveFen)));
    } catch {
      // The live FEN is the server's own; if even that will not load, show what replayed.
    }
  }
  return { positions, moves };
}

// ---------------------------------------------------------------------------- the local model

const positionCache = new Map();
const POSITION_CACHE_LIMIT = 4000;

/**
 * Every legal move from a position, valued by the local model from the mover's point of view
 * and sorted best first. Pure in the FEN, so it is computed once per position ever seen.
 */
export function scorePosition(fen) {
  const hit = positionCache.get(fen);
  if (hit) return hit;

  const walker = new Chess(fen);
  const color = walker.turn();
  const candidates = walker.moves({ verbose: true }).map((m) => {
    walker.move({ from: m.from, to: m.to, promotion: m.promotion });
    const { v, terminal } = evaluate(walker, color);
    walker.undo();
    return { san: m.san, from: m.from, to: m.to, uci: `${m.from}${m.to}${m.promotion ?? ''}`, v, terminal };
  });
  candidates.sort((a, b) => b.v - a.v || a.san.localeCompare(b.san));

  const scored = { color, candidates, vs: candidates.map((c) => c.v) };
  positionCache.set(fen, scored);
  if (positionCache.size > POSITION_CACHE_LIMIT) positionCache.delete(positionCache.keys().next().value);
  return scored;
}

/**
 * One decision per position: the moves available, the one played (if any), and -- once β is
 * fitted -- the policy's probabilities and the information measures that follow from them.
 */
function decide(position, move) {
  const { color, candidates, vs } = scorePosition(position.fen);
  const playedIndex = move ? candidates.findIndex((c) => c.uci === move.uci) : -1;
  const vPlayed = playedIndex >= 0 ? vs[playedIndex] : null;
  return {
    fen: position.fen,
    color,
    candidates,
    vs,
    branching: vs.length,
    playedIndex,
    rank: playedIndex >= 0 ? playedIndex + 1 : null,
    vPlayed,
    regret: vPlayed === null ? null : vs[0] - vPlayed,
  };
}

/** Fit β per side by maximum likelihood, then derive probabilities, entropy and surprise. */
function finish(decisions) {
  const players = {};
  for (const color of ['w', 'b']) {
    const rows = decisions.filter((d) => d.color === color && d.playedIndex >= 0 && d.vs.length > 1);
    const fit = rows.length ? fitBeta(rows) : { beta: DEFAULT_BETA, logLik: 0, perMove: 0 };
    players[color] = { ...fit, fitted: rows.length > 0, moves: rows.length };
  }

  const done = decisions.map((d) => {
    const beta = players[d.color].beta;
    const probs = softmax(d.vs, beta);
    const entropy = entropyBits(probs);
    const maxEntropy = log2(Math.max(d.branching, 1));
    const pPlayed = d.playedIndex >= 0 ? probs[d.playedIndex] : null;
    return {
      ...d,
      beta,
      probs,
      entropy,
      maxEntropy,
      focus: maxEntropy > 0 ? 1 - entropy / maxEntropy : 1,
      pPlayed,
      surprisal: pPlayed ? -log2(pPlayed) : null,
    };
  });

  for (const color of ['w', 'b']) {
    const rows = done.filter((d) => d.color === color && d.surprisal !== null && d.vs.length > 1);
    const mean = (f) => (rows.length ? rows.reduce((a, r) => a + f(r), 0) / rows.length : null);
    const share = (f) => (rows.length ? rows.filter(f).length / rows.length : null);
    const crossEntropy = mean((r) => r.surprisal);
    const uniformBits = mean((r) => r.maxEntropy);
    Object.assign(players[color], {
      crossEntropy,
      perplexity: crossEntropy === null ? null : 2 ** crossEntropy,
      uniformBits,
      bitsExplained: crossEntropy === null ? null : uniformBits - crossEntropy,
      meanEntropy: mean((r) => r.entropy),
      meanBranching: mean((r) => r.branching),
      top1: share((r) => r.rank === 1),
      top3: share((r) => r.rank <= 3),
    });
  }

  return { decisions: done, players };
}

/**
 * Runs the local model over a game, live: only positions never seen before cost anything, and
 * that work is spread over ~12ms slices so the board stays responsive. During play, a new move
 * scores one new position and refits β -- a few milliseconds.
 */
export function useLocalPolicy(positions, moves) {
  const [state, setState] = useState({ decisions: [], players: null, progress: 0, running: false });
  const generation = useRef(0);

  useEffect(() => {
    const run = ++generation.current;
    if (!positions.length) {
      setState({ decisions: [], players: null, progress: 0, running: false });
      return;
    }

    const decisions = new Array(positions.length);
    let next = 0;
    let timer = 0;

    const slice = () => {
      if (run !== generation.current) return;
      const started = performance.now();
      while (next < positions.length && performance.now() - started < 12) {
        decisions[next] = decide(positions[next], moves[next] ?? null);
        next++;
      }
      if (next < positions.length) {
        setState((s) => ({ ...s, progress: next / positions.length, running: true }));
        timer = setTimeout(slice, 0);
        return;
      }
      setState({ ...finish(decisions), progress: 1, running: false });
    };

    slice();
    return () => clearTimeout(timer);
  }, [positions, moves]);

  return state;
}
