// Where the engine and the model meet: one row per move, and the per-side numbers built on them.

/**
 * Win chance, in percent, for an evaluation from the mover's point of view.
 *
 * A logistic in centipawns, fitted to real game outcomes; this is the curve Lichess publishes.
 * Evaluations are capped at ±10 pawns, beyond which the outcome is not in doubt.
 */
export function winChance(pawns) {
  const cp = Math.max(-1000, Math.min(1000, pawns * 100));
  return 50 + 50 * (2 / (1 + Math.exp(-0.00368208 * cp)) - 1);
}

/**
 * How accurate a move was, in percent, from the win chance it gave up. An exponential decay:
 * a free move scores 100, giving away 10 points of win chance scores about 62, 30 points about 24.
 */
export function moveAccuracy(winBefore, winAfter) {
  if (winAfter >= winBefore) return 100;
  const raw = 103.1668 * Math.exp(-0.04354 * (winBefore - winAfter)) - 3.1669;
  return Math.max(0, Math.min(100, raw));
}

/** Win chance thrown away by a single move, in percentage points, and what it is called. */
export const SEVERITY = [
  { key: 'blunder', label: 'Blunder', min: 30 },
  { key: 'mistake', label: 'Mistake', min: 20 },
  { key: 'inaccuracy', label: 'Inaccuracy', min: 10 },
];

export function classify(winLost) {
  if (!Number.isFinite(winLost)) return null;
  return SEVERITY.find((s) => winLost >= s.min)?.key ?? null;
}

/**
 * One row per move: what the engine thought before and after it, what the model expected, and
 * what that says about the move.
 *
 * Engine values are null until the position has been evaluated; every derived number is null
 * with them, and the charts leave a gap rather than inventing a value.
 */
export function moveRows(moves, decisions, points) {
  return moves.map((move, k) => {
    const decision = decisions[k] ?? null;
    const before = points[k]?.pawns;
    const after = points[k + 1]?.pawns;
    const sign = move.color === 'w' ? 1 : -1;
    const judged = Number.isFinite(before) && Number.isFinite(after);

    const winBefore = judged ? winChance(sign * before) : null;
    const winAfter = judged ? winChance(sign * after) : null;
    const winLost = judged ? Math.max(0, winBefore - winAfter) : null;
    const engineBest = points[k]?.best ?? null;

    return {
      k,
      ply: k + 1,
      moveNo: Math.floor(k / 2) + 1,
      label: `${Math.floor(k / 2) + 1}${move.color === 'w' ? '.' : '…'} ${move.san}`,
      color: move.color,
      san: move.san,
      uci: move.uci,
      evalAfter: Number.isFinite(after) ? after : null,
      pawnsLost: judged ? Math.max(0, sign * before - sign * after) : null,
      winBefore,
      winAfter,
      winLost,
      accuracy: judged ? moveAccuracy(winBefore, winAfter) : null,
      severity: judged ? classify(winLost) : null,
      engineBest,
      matched: engineBest ? engineBest === move.uci : null,
      branching: decision?.branching ?? null,
      rank: decision?.rank ?? null,
      pPlayed: decision?.pPlayed ?? null,
      surprisal: decision?.surprisal ?? null,
      entropy: decision?.entropy ?? null,
    };
  });
}

const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);

/** One side's game in numbers. Anything that needs the engine is null until it has answered. */
export function sideSummary(rows, color, player) {
  const mine = rows.filter((r) => r.color === color);
  const judged = mine.filter((r) => r.winLost !== null);
  const count = (key) => judged.filter((r) => r.severity === key).length;

  return {
    moves: mine.length,
    judged: judged.length,
    accuracy: mean(judged.map((r) => r.accuracy)),
    acpl: judged.length ? mean(judged.map((r) => r.pawnsLost)) * 100 : null,
    engineMatch: judged.length ? judged.filter((r) => r.matched).length / judged.length : null,
    inaccuracies: count('inaccuracy'),
    mistakes: count('mistake'),
    blunders: count('blunder'),
    worst: judged.reduce((w, r) => (w === null || r.winLost > w.winLost ? r : w), null),
    beta: player?.fitted ? player.beta : null,
    perplexity: player?.perplexity ?? null,
    crossEntropy: player?.crossEntropy ?? null,
    bitsExplained: player?.bitsExplained ?? null,
    meanBranching: player?.meanBranching ?? null,
    top1: player?.top1 ?? null,
    top3: player?.top3 ?? null,
  };
}

/** A plain-language reading of an evaluation, for the line under the big number. */
export function describeEvaluation(pawns, mate) {
  if (mate !== null && mate !== undefined && Number.isFinite(mate) && mate !== 0) {
    return `Forced mate${Math.abs(mate) > 1 ? ` in ${Math.abs(mate)}` : ''}`;
  }
  if (!Number.isFinite(pawns)) return '';
  const side = pawns > 0 ? 'White' : 'Black';
  const size = Math.abs(pawns);
  if (size < 0.3) return 'Dead level';
  if (size < 1) return `${side} is slightly better`;
  if (size < 2.5) return `${side} is clearly better`;
  if (size < 5) return `${side} is winning`;
  return `${side} is completely winning`;
}
