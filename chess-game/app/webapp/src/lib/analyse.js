import { useEffect, useMemo, useState } from 'react';
import { Chess } from 'chess.js';
import { evaluate, softmax, entropyBits, fitBeta } from './model.js';

const LOG2 = Math.log(2);
const log2 = (x) => Math.log(x) / LOG2;
const DEFAULT_BETA = 2;

/**
 * Reads a game (PGN) or a single position (FEN) into the frames the board steps through.
 * Cheap enough to run synchronously: one pass, no move scoring.
 */
export function useGame({ pgn, fen }) {
  return useMemo(() => {
    try {
      const game = new Chess();
      if (pgn) {
        game.loadPgn(pgn);
        const history = game.history({ verbose: true });
        const replay = new Chess();
        const frame = () => ({ board: replay.board(), fen: replay.fen(), turn: replay.turn() });
        const positions = [{ ...frame(), squares: [] }];
        for (const m of history) {
          replay.move(m);
          positions.push({ ...frame(), squares: [m.from, m.to] });
        }
        return { positions, moves: history.map((m) => m.san), error: null };
      }
      game.load(fen);
      return {
        positions: [{ board: game.board(), fen: game.fen(), turn: game.turn(), squares: [] }],
        moves: [],
        error: null,
      };
    } catch (e) {
      return { positions: [], moves: [], error: e.message };
    }
  }, [pgn, fen]);
}

/**
 * Walks a game one ply at a time, scoring every legal move at every position.
 * `step()` does one ply so the caller can spread the work over several frames.
 */
function createAnalyser({ pgn, fen }) {
  const walker = new Chess();
  let history = [];
  if (pgn) {
    walker.loadPgn(pgn);
    history = walker.history({ verbose: true });
    walker.reset();
  } else {
    walker.load(fen);
  }

  const total = pgn ? history.length : 1;
  const plies = [];
  let t = 0;

  // Value, from `color`'s point of view, of every position `color` can reach from here.
  function scoreCandidates(color) {
    const scored = walker.moves({ verbose: true }).map((m) => {
      walker.move({ from: m.from, to: m.to, promotion: m.promotion });
      const { v, terminal } = evaluate(walker, color);
      walker.undo();
      return { san: m.san, from: m.from, to: m.to, v, terminal };
    });
    scored.sort((a, b) => b.v - a.v || a.san.localeCompare(b.san));
    return scored;
  }

  return {
    total,
    get completed() {
      return t;
    },
    get done() {
      return t >= total;
    },

    step() {
      const color = walker.turn();
      const candidates = scoreCandidates(color);
      const vs = candidates.map((c) => c.v);
      const played = pgn ? history[t] : null;

      let playedIndex = -1;
      if (played) {
        playedIndex = candidates.findIndex((c) => c.san === played.san);
        if (playedIndex < 0) {
          playedIndex = candidates.findIndex((c) => c.from === played.from && c.to === played.to);
        }
      }
      const vPlayed = playedIndex >= 0 ? vs[playedIndex] : null;

      plies.push({
        index: t,
        ply: t + 1,
        moveNo: Math.floor(t / 2) + 1,
        color,
        san: played?.san ?? null,
        from: played?.from ?? null,
        to: played?.to ?? null,
        uci: played ? `${played.from}${played.to}${played.promotion ?? ''}` : null,
        candidates,
        vs,
        playedIndex,
        branching: vs.length,
        vBest: vs[0] ?? 0,
        vPlayed,
        regret: vPlayed === null ? null : vs[0] - vPlayed,
        rank: playedIndex < 0 ? null : playedIndex + 1,
      });

      if (played) walker.move({ from: played.from, to: played.to, promotion: played.promotion });
      t++;
    },

    /** Fit β per side by maximum likelihood, then derive the information measures. */
    finish() {
      const players = {};
      for (const color of ['w', 'b']) {
        const rows = plies.filter((p) => p.color === color && p.playedIndex >= 0 && p.vs.length > 1);
        const fit = rows.length ? fitBeta(rows) : { beta: DEFAULT_BETA, logLik: 0, perMove: 0 };
        players[color] = { ...fit, fitted: rows.length > 0 };
      }

      for (const p of plies) {
        const beta = players[p.color].beta;
        p.beta = beta;
        p.probs = softmax(p.vs, beta);
        p.entropy = entropyBits(p.probs);
        p.maxEntropy = log2(Math.max(p.branching, 1));
        p.focus = p.maxEntropy > 0 ? 1 - p.entropy / p.maxEntropy : 1;
        p.pPlayed = p.playedIndex >= 0 ? p.probs[p.playedIndex] : null;
        p.surprisal = p.pPlayed ? -log2(p.pPlayed) : null;
      }

      for (const color of ['w', 'b']) {
        const rows = plies.filter(
          (p) => p.color === color && p.surprisal !== null && p.vs.length > 1
        );
        const mean = (f) => (rows.length ? rows.reduce((a, r) => a + f(r), 0) / rows.length : 0);
        const share = (f) => (rows.length ? rows.filter(f).length / rows.length : 0);
        const crossEntropy = mean((r) => r.surprisal);
        const uniformBits = mean((r) => r.maxEntropy);
        Object.assign(players[color], {
          moves: rows.length,
          crossEntropy,
          perplexity: 2 ** crossEntropy,
          uniformBits,
          bitsExplained: uniformBits - crossEntropy,
          meanEntropy: mean((r) => r.entropy),
          meanBranching: mean((r) => r.branching),
          meanFocus: mean((r) => r.focus),
          meanRegret: mean((r) => r.regret),
          top1: share((r) => r.rank === 1),
          top3: share((r) => r.rank <= 3),
        });
      }

      return { plies, players, mode: pgn ? 'game' : 'position' };
    },
  };
}

const IDLE = { phase: 'idle', progress: 0, plies: [], players: null, mode: null, error: null };

/**
 * Runs the candidate scoring in ~12ms slices, so the board stays responsive while the policy
 * numbers fill in. This is the part that has to be local: ranking all ~35 legal moves at every
 * ply is thousands of positions, far more than an API round trip per position can carry.
 */
export function useLocalPolicy({ pgn, fen }) {
  const [state, setState] = useState(IDLE);

  useEffect(() => {
    if (!pgn && !fen) {
      setState(IDLE);
      return;
    }

    let analyser;
    try {
      analyser = createAnalyser({ pgn, fen });
    } catch (e) {
      setState({ ...IDLE, phase: 'error', error: e.message });
      return;
    }

    let cancelled = false;
    let timer = 0;
    setState({ ...IDLE, phase: 'running' });

    const slice = () => {
      if (cancelled) return;
      const started = performance.now();
      let steps = 0;
      while (!analyser.done && performance.now() - started < 12) {
        analyser.step();
        steps++;
      }
      if (analyser.done) {
        setState({ phase: 'done', progress: 1, error: null, ...analyser.finish() });
        return;
      }
      if (steps > 0) {
        setState((s) => ({ ...s, progress: analyser.completed / analyser.total }));
      }
      timer = setTimeout(slice, 0);
    };

    timer = setTimeout(slice, 0);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [pgn, fen]);

  return state;
}
