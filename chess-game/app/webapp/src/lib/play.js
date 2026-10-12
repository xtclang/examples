import { useCallback, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Chess } from 'chess.js';
import { getGameState, getValidMoves, playMove, resetGame } from '../api.js';
import { replayHistory } from './analyse.js';

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

/** The inverse, for applying a move locally before the server has confirmed it. */
function toRows(board) {
  return board.map((rank) =>
    rank.map((cell) => (cell ? (cell.color === 'w' ? cell.type.toUpperCase() : cell.type) : '.')).join('')
  );
}

export function moveSquares(lastMove) {
  return typeof lastMove === 'string' && lastMove.length >= 4
    ? [lastMove.slice(0, 2), lastMove.slice(2, 4)]
    : [];
}

/** While the computer is thinking, how often to ask whether its move has landed. */
const POLL_MS = 900;

/**
 * Plays one game against the computer.
 *
 * TanStack Query owns the game: one query per session, polled only while the computer is
 * thinking -- the server applies its reply on the first request after the thinking delay, so
 * polling is what makes the reply appear. Moves are applied optimistically, so a piece moves the
 * instant it is put down, and rolled back if the server refuses.
 */
export function usePlay() {
  const [sessionId] = useState(ensureSession);
  const client = useQueryClient();
  const key = useMemo(() => ['game', sessionId], [sessionId]);

  const game = useQuery({
    queryKey: key,
    queryFn: () => getGameState(sessionId),
    refetchInterval: (query) => (query.state.data?.opponentPending ? POLL_MS : false),
    refetchOnWindowFocus: true,
  });
  const state = game.data ?? null;

  const [selected, setSelectedState] = useState(null);
  const [targets, setTargets] = useState([]);
  // The selection as of now, for async work that finishes after the user has moved on.
  const selectedRef = useRef(null);
  const setSelected = useCallback((square) => {
    selectedRef.current = square;
    setSelectedState(square);
  }, []);

  const clearSelection = useCallback(() => {
    setSelected(null);
    setTargets([]);
  }, [setSelected]);

  const move = useMutation({
    mutationFn: ({ from, to }) => playMove(sessionId, from, to),
    onMutate: async ({ from, to }) => {
      await client.cancelQueries({ queryKey: key });
      const previous = client.getQueryData(key);
      if (previous?.fen) {
        try {
          const local = new Chess(previous.fen);
          const piece = local.get(from);
          const promoting = piece?.type === 'p' && (to[1] === '8' || to[1] === '1');
          const made = local.move({ from, to, promotion: promoting ? 'q' : undefined });
          client.setQueryData(key, {
            ...previous,
            board: toRows(local.board()),
            fen: local.fen(),
            turn: 'Black',
            lastMove: `${from}${to}`,
            opponentPending: true,
            message: `You moved ${made.san}.`,
            moveHistory: [
              ...previous.moveHistory,
              { color: 'White', fromSquare: from, toSquare: to, promotion: made.promotion ?? null, notation: made.san },
            ],
          });
        } catch {
          // Not legal by chess.js either; let the server answer and say why.
        }
      }
      return { previous };
    },
    onError: (_error, _move, context) => {
      if (context?.previous) client.setQueryData(key, context.previous);
    },
    onSuccess: (next) => client.setQueryData(key, next),
  });

  const restart = useMutation({
    mutationFn: ({ timeControlMs = 0, incrementMs = 0 } = {}) =>
      resetGame(sessionId, timeControlMs, incrementMs),
    onSuccess: (next) => {
      clearSelection();
      client.setQueryData(key, next);
    },
  });

  const playable =
    state?.status === 'Ongoing' && state?.turn === 'White' && !state?.opponentPending && !move.isPending;

  /** Click a square: pick up a piece, put it down, or switch to another piece. */
  const touch = useCallback(
    async (square) => {
      if (!playable || !state) return;

      if (selected === square) {
        clearSelection();
        return;
      }
      if (selected && targets.includes(square)) {
        const from = selected;
        clearSelection();
        move.mutate({ from, to: square });
        return;
      }

      // Show the moves at once from the local rules, then confirm them with the server, which
      // has the final say.
      let local = [];
      try {
        local = new Chess(state.fen).moves({ square, verbose: true }).map((m) => m.to);
      } catch {
        local = [];
      }
      if (!local.length) {
        clearSelection();
        return;
      }
      setSelected(square);
      setTargets([...new Set(local)]);

      try {
        const reply = await client.fetchQuery({
          queryKey: ['valid-moves', sessionId, state.fen, square],
          queryFn: () => getValidMoves(sessionId, square),
          staleTime: Infinity,
        });
        if (selectedRef.current === square) {
          setTargets(reply.success ? reply.validMoves ?? [] : []);
        }
      } catch {
        // Keep the local answer; the server still validates the move itself.
      }
    },
    [playable, state, selected, targets, setSelected, clearSelection, move, client, sessionId]
  );

  const frames = useMemo(
    () => replayHistory(state?.moveHistory ?? [], state?.fen ?? null),
    [state?.moveHistory, state?.fen]
  );

  return {
    sessionId,
    state,
    frames,
    loading: game.isPending,
    error: game.error?.message ?? move.error?.message ?? restart.error?.message ?? '',
    thinking: Boolean(state?.opponentPending),
    playable,
    selected,
    targets,
    touch,
    clearSelection,
    restart: (timeControlMs, incrementMs) => restart.mutate({ timeControlMs, incrementMs }),
    restarting: restart.isPending,
  };
}
