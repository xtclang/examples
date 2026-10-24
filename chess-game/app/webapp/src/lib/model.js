// A transparent, fully client-side model of how a player chooses a move.
//
//   V(p)      = wᵀφ(p)                       linear value of a position
//   P(m | p)  = softmax over legal m of β·V(p∘m)   bounded-rationality policy
//   β̂         = argmax_β Σ_t log P(m*_t | p_t)     fitted to the moves actually played
//
// Every feature is written from the point of view of the player who just moved,
// so V is "good for me" and the softmax is a plain maximisation.

export const PIECE_VALUE = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 0 };

// Piece-square tables in centipawns, row 0 = rank 8 (the order chess.js board() uses).
// Black reads the same table mirrored across the horizontal axis.
const PST = {
  p: [
    [  0,  0,  0,  0,  0,  0,  0,  0],
    [ 50, 50, 50, 50, 50, 50, 50, 50],
    [ 10, 10, 20, 30, 30, 20, 10, 10],
    [  5,  5, 10, 25, 25, 10,  5,  5],
    [  0,  0,  0, 20, 20,  0,  0,  0],
    [  5, -5,-10,  0,  0,-10, -5,  5],
    [  5, 10, 10,-20,-20, 10, 10,  5],
    [  0,  0,  0,  0,  0,  0,  0,  0],
  ],
  n: [
    [-50,-40,-30,-30,-30,-30,-40,-50],
    [-40,-20,  0,  0,  0,  0,-20,-40],
    [-30,  0, 10, 15, 15, 10,  0,-30],
    [-30,  5, 15, 20, 20, 15,  5,-30],
    [-30,  0, 15, 20, 20, 15,  0,-30],
    [-30,  5, 10, 15, 15, 10,  5,-30],
    [-40,-20,  0,  5,  5,  0,-20,-40],
    [-50,-40,-30,-30,-30,-30,-40,-50],
  ],
  b: [
    [-20,-10,-10,-10,-10,-10,-10,-20],
    [-10,  0,  0,  0,  0,  0,  0,-10],
    [-10,  0,  5, 10, 10,  5,  0,-10],
    [-10,  5,  5, 10, 10,  5,  5,-10],
    [-10,  0, 10, 10, 10, 10,  0,-10],
    [-10, 10, 10, 10, 10, 10, 10,-10],
    [-10,  5,  0,  0,  0,  0,  5,-10],
    [-20,-10,-10,-10,-10,-10,-10,-20],
  ],
  r: [
    [  0,  0,  0,  0,  0,  0,  0,  0],
    [  5, 10, 10, 10, 10, 10, 10,  5],
    [ -5,  0,  0,  0,  0,  0,  0, -5],
    [ -5,  0,  0,  0,  0,  0,  0, -5],
    [ -5,  0,  0,  0,  0,  0,  0, -5],
    [ -5,  0,  0,  0,  0,  0,  0, -5],
    [ -5,  0,  0,  0,  0,  0,  0, -5],
    [  0,  0,  0,  5,  5,  0,  0,  0],
  ],
  q: [
    [-20,-10,-10, -5, -5,-10,-10,-20],
    [-10,  0,  0,  0,  0,  0,  0,-10],
    [-10,  0,  5,  5,  5,  5,  0,-10],
    [ -5,  0,  5,  5,  5,  5,  0, -5],
    [  0,  0,  5,  5,  5,  5,  0, -5],
    [-10,  5,  5,  5,  5,  5,  0,-10],
    [-10,  0,  5,  0,  0,  0,  0,-10],
    [-20,-10,-10, -5, -5,-10,-10,-20],
  ],
  k: [
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-30,-40,-40,-50,-50,-40,-40,-30],
    [-20,-30,-30,-40,-40,-30,-30,-20],
    [-10,-20,-20,-20,-20,-20,-20,-10],
    [ 20, 20,  0,  0,  0,  0, 20, 20],
    [ 20, 30, 10,  0,  0, 10, 30, 20],
  ],
};

// The six features, with the weights that turn them into pawns.
export const FEATURES = [
  { key: 'material',  label: 'Material',       symbol: 'φ₁', w:  0.010, unit: 'cp',
    note: 'Σ own piece values − Σ opponent piece values' },
  { key: 'placement', label: 'Placement',      symbol: 'φ₂', w:  0.010, unit: 'cp',
    note: 'Piece-square table, own − opponent' },
  { key: 'structure', label: 'Pawn structure', symbol: 'φ₃', w: -0.180, unit: 'pawns',
    note: 'Doubled + isolated pawns, own − opponent' },
  { key: 'shield',    label: 'King shield',    symbol: 'φ₄', w:  0.140, unit: 'pawns',
    note: 'Own pawns guarding own king, own − opponent' },
  { key: 'restraint', label: 'Restraint',      symbol: 'φ₅', w: -0.015, unit: 'replies',
    note: 'Legal replies left to the opponent' },
  { key: 'tempo',     label: 'Tempo',          symbol: 'φ₆', w:  0.300, unit: '0 / 1',
    note: '1 when the move gives check' },
  { key: 'exposure',  label: 'Exposure',       symbol: 'φ₇', w: -0.010, unit: 'cp',
    note: 'Most material the opponent can win by exchange in reply' },
];

const MATE = 30; // pawns; large enough to dominate, small enough for a stable softmax

const FILES = 'abcdefgh';

function scan(board) {
  const acc = {
    w: { material: 0, placement: 0, pawnFiles: new Array(8).fill(0), king: null },
    b: { material: 0, placement: 0, pawnFiles: new Array(8).fill(0), king: null },
  };
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const cell = board[r][c];
      if (!cell) continue;
      const side = acc[cell.color];
      side.material += PIECE_VALUE[cell.type];
      side.placement += PST[cell.type][cell.color === 'w' ? r : 7 - r][c];
      if (cell.type === 'p') side.pawnFiles[c]++;
      if (cell.type === 'k') side.king = { r, c };
    }
  }
  return acc;
}

// Doubled pawns plus pawns with no friendly pawn on either neighbouring file.
function structure(pawnFiles) {
  let penalty = 0;
  for (let f = 0; f < 8; f++) {
    const n = pawnFiles[f];
    if (!n) continue;
    penalty += n - 1;
    const left = f > 0 ? pawnFiles[f - 1] : 0;
    const right = f < 7 ? pawnFiles[f + 1] : 0;
    if (!left && !right) penalty += n;
  }
  return penalty;
}

// Own pawns on the king's file or either neighbour, within two ranks in front.
function shield(board, king, color) {
  if (!king) return 0;
  const forward = color === 'w' ? -1 : 1;
  let count = 0;
  for (let df = -1; df <= 1; df++) {
    const c = king.c + df;
    if (c < 0 || c > 7) continue;
    for (let step = 1; step <= 2; step++) {
      const r = king.r + forward * step;
      if (r < 0 || r > 7) continue;
      const cell = board[r][c];
      if (cell && cell.type === 'p' && cell.color === color) count++;
    }
  }
  return count;
}

/**
 * Feature vector of the position reached *after* `color` has moved, written from
 * `color`'s point of view. `game` must be sitting on that position, so the side
 * to move is the opponent.
 */
export function featureVector(game, color) {
  const board = game.board();
  const them = color === 'w' ? 'b' : 'w';
  const s = scan(board);
  const mine = s[color];
  const theirs = s[them];

  // The opponent's reply list is generated once and read twice: how many options they have,
  // and the best exchange they can win from it. Without this second term the model has no idea
  // that a piece is hanging, and it mispredicts almost every real move.
  const replies = game.moves({ verbose: true });
  let exposure = 0;
  for (const reply of replies) {
    if (!reply.captured) continue;
    const gain = PIECE_VALUE[reply.captured] - PIECE_VALUE[reply.piece];
    if (gain > exposure) exposure = gain;
  }

  return {
    material: mine.material - theirs.material,
    placement: mine.placement - theirs.placement,
    structure: structure(mine.pawnFiles) - structure(theirs.pawnFiles),
    shield: shield(board, mine.king, color) - shield(board, theirs.king, them),
    restraint: replies.length,
    tempo: game.isCheck() ? 1 : 0,
    exposure,
  };
}

export function value(phi) {
  let v = 0;
  for (const f of FEATURES) v += f.w * phi[f.key];
  return v;
}

/** Value in pawns of the position after `color` moved, from `color`'s point of view. */
export function evaluate(game, color) {
  if (game.isCheckmate()) return { v: MATE, phi: null, terminal: 'mate' };
  if (game.isDraw() || game.isStalemate()) return { v: 0, phi: null, terminal: 'draw' };
  const phi = featureVector(game, color);
  return { v: value(phi), phi, terminal: null };
}

// ---------------------------------------------------------------- the policy

/** Numerically safe softmax of β·v. */
export function softmax(vs, beta) {
  let max = -Infinity;
  for (const v of vs) if (beta * v > max) max = beta * v;
  let sum = 0;
  const out = new Array(vs.length);
  for (let i = 0; i < vs.length; i++) {
    out[i] = Math.exp(beta * vs[i] - max);
    sum += out[i];
  }
  for (let i = 0; i < out.length; i++) out[i] /= sum;
  return out;
}

/** log P(played | β) for one decision, via log-sum-exp. */
function logProb(vs, playedIndex, beta) {
  let max = -Infinity;
  for (const v of vs) if (beta * v > max) max = beta * v;
  let sum = 0;
  for (const v of vs) sum += Math.exp(beta * v - max);
  return beta * vs[playedIndex] - (max + Math.log(sum));
}

const logLikelihood = (rows, beta) =>
  rows.reduce((acc, r) => acc + logProb(r.vs, r.playedIndex, beta), 0);

/**
 * Maximum-likelihood β. The log-partition function is convex in β, so the
 * log-likelihood is concave and a ternary search finds the global optimum.
 */
export function fitBeta(rows, lo = 0, hi = 8, iterations = 60) {
  if (rows.length === 0) return { beta: 0, logLik: 0, perMove: 0 };
  for (let i = 0; i < iterations; i++) {
    const a = lo + (hi - lo) / 3;
    const b = hi - (hi - lo) / 3;
    if (logLikelihood(rows, a) < logLikelihood(rows, b)) lo = a;
    else hi = b;
  }
  const beta = (lo + hi) / 2;
  const logLik = logLikelihood(rows, beta);
  return { beta, logLik, perMove: logLik / rows.length };
}

const LOG2 = Math.log(2);

export function entropyBits(ps) {
  let h = 0;
  for (const p of ps) if (p > 0) h -= p * Math.log(p);
  return h / LOG2;
}
