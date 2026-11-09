import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { analyseMoveChoices, replayPgn } from '../api.js';
import { toMatrix } from './play.js';

export const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

// ---------------------------------------------------------------------------- games as frames
//
// Both modes reduce to the same shape: the positions of a game, `{ board, fen, turn, squares }`,
// and the moves between them, `{ from, to, promotion, san, color, uci }`. Everything downstream
// -- the board, the engine, the model, the charts -- reads only that.

/** Expands a FEN board field's `/`-separated, digit-compressed ranks into 8 row strings. Pure
 *  syntax decoding -- no chess rules -- the same as reading any other text format. */
function fenBoardRows(fenBoardField) {
  return fenBoardField.split('/').map((rank) =>
    [...rank].map((ch) => (/[1-8]/.test(ch) ? '.'.repeat(Number(ch)) : ch)).join('')
  );
}

/** One static position, with no moves -- the "starting position" or a bare FEN source. */
function singleFrame(fen) {
  return { board: toMatrix(fenBoardRows(fen.split(' ')[0])), fen, turn: fen.split(' ')[1], squares: [] };
}

/** The backend's flat 64-char board string, reshaped into the 8 row strings `toMatrix` wants. */
function flatBoardRows(flat) {
  return Array.from({ length: 8 }, (_, i) => flat.slice(i * 8, i * 8 + 8));
}

/** A frame from the server's PGN replay (see PgnReplayApi.x). */
function frameFromReplay(f) {
  return {
    board: toMatrix(flatBoardRows(f.board)),
    fen: f.fen,
    turn: f.fen.split(' ')[1],
    squares: f.fromSquare && f.toSquare ? [f.fromSquare, f.toSquare] : [],
  };
}

function moveFromReplay(f) {
  return {
    from: f.fromSquare,
    to: f.toSquare,
    promotion: f.promotion,
    san: f.notation,
    color: f.color === 'White' ? 'w' : 'b',
    uci: `${f.fromSquare}${f.toSquare}${f.promotion ?? ''}`,
  };
}

/**
 * The game being played against the server (single-player or online), as frames.
 *
 * The server now sends the FEN and board for the position after each move directly on its
 * `moveHistory` entries (see [MoveHistoryEntry] / [ChessGame.applyMove]), so this is pure
 * reshaping of fields the backend already computed -- no local replay needed.
 */
export function gameFrames(moveHistory = []) {
  const positions = [singleFrame(START_FEN)];
  const moves = [];
  for (const entry of moveHistory) {
    positions.push({
      board: toMatrix(flatBoardRows(entry.boardAfter)),
      fen: entry.fen,
      turn: entry.fen.split(' ')[1],
      squares: [entry.fromSquare, entry.toSquare],
    });
    moves.push({
      from: entry.fromSquare,
      to: entry.toSquare,
      promotion: entry.promotion ? entry.promotion.toLowerCase() : null,
      san: entry.notation,
      color: entry.color === 'White' ? 'w' : 'b',
      uci: `${entry.fromSquare}${entry.toSquare}${entry.promotion ? entry.promotion.toLowerCase() : ''}`,
    });
  }
  return { positions, moves };
}

/**
 * A game from chess.com (PGN) or a single position (FEN), as frames.
 *
 * Resolving PGN's SAN moves into from/to squares needs the position's legal moves to
 * disambiguate (e.g. "Nbd7"), which only the server's chess rules can answer -- see
 * [PgnReplayApi.x]. A bare FEN with no PGN is just one static position, which needs no rules to
 * display, so that path stays local.
 */
export function useGame({ pgn, fen }) {
  const startFen = fen ?? START_FEN;
  const query = useQuery({
    queryKey: ['replay', startFen, pgn ?? null],
    queryFn: () => replayPgn(startFen, pgn),
    enabled: Boolean(pgn),
    staleTime: Infinity,
  });

  return useMemo(() => {
    if (!pgn) {
      return { positions: [singleFrame(startFen)], moves: [], error: null };
    }
    if (query.isError) {
      return { positions: [], moves: [], error: query.error.message };
    }
    if (!query.data) {
      return { positions: [], moves: [], error: null };
    }
    const frames = query.data;
    return {
      positions: frames.map(frameFromReplay),
      moves: frames.slice(1).map(moveFromReplay),
      error: null,
    };
  }, [pgn, startFen, query.data, query.isError, query.error]);
}

// ---------------------------------------------------------------------------- the move-choice model
//
// Scoring every legal move at every position (material/placement/pawn-structure/king-safety
// features, weighted into a value) and fitting the softmax policy's beta by maximum likelihood
// used to run here; it now runs on the server, which already has the chess rules this needs
// (legal moves, check detection) -- see ModelApi.x / MoveModel.x. This just asks for the numbers
// and returns them in the same shape MetricsPanel.jsx has always read.

/**
 * The model's read on a game: one decision per position (the moves available, the one played,
 * and the policy's probabilities for each), and the fitted beta and summary stats per side.
 */
export function useLocalPolicy(positions, moves) {
  const fens = useMemo(() => positions.map((p) => p.fen), [positions]);
  const playedUci = useMemo(() => moves.map((m) => m.uci), [moves]);

  const query = useQuery({
    queryKey: ['model-analyse', fens, playedUci],
    queryFn: () => analyseMoveChoices(fens, playedUci),
    enabled: fens.length > 0,
    staleTime: Infinity,
  });

  return useMemo(() => {
    if (!query.data) {
      return { decisions: [], players: null, progress: 0, running: fens.length > 0 };
    }
    return { decisions: query.data.decisions, players: query.data.players, progress: 1, running: false };
  }, [query.data, fens.length]);
}
