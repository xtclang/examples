import { useCallback, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { getGameState, getValidMoves, playMove, resetGame } from '../api.js';
import { gameFrames } from './analyse.js';

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

  // While the move mutation is in flight, the optimistic update already marks the game as
  // opponentPending -- which would otherwise make the poller fire a GET /state before the POST
  // /move has landed. That GET still sees the pre-move position and overwrites the optimistic
  // board with it, so the piece jumps back and then forward again once the real reply arrives:
  // the move visibly "plays twice". Holding the poller off until the mutation settles avoids it.
  const movingRef = useRef(false);

  const game = useQuery({
    queryKey: key,
    queryFn: () => getGameState(sessionId),
    refetchInterval: (query) => (!movingRef.current && query.state.data?.opponentPending ? POLL_MS : false),
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
    // No optimistic board update: the server is the only thing that decides what a move does
    // (legality, captures, promotion, check). The piece appears once the server replies; until
    // then `move.isPending` (via `playable`, below) keeps the board from accepting more input.
    onMutate: async () => {
      movingRef.current = true;
      await client.cancelQueries({ queryKey: key });
      return { previous: client.getQueryData(key) };
    },
    onError: (_error, _move, context) => {
      if (context?.previous) client.setQueryData(key, context.previous);
    },
    onSuccess: (next) => client.setQueryData(key, next),
    onSettled: () => {
      movingRef.current = false;
      client.invalidateQueries({ queryKey: key });
    },
  });

  const restart = useMutation({
    mutationFn: ({ timeControlMs = 0, incrementMs = 0, difficulty = 'strong' } = {}) =>
      resetGame(sessionId, timeControlMs, incrementMs, difficulty),
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

      // Legal targets come from the server; there is no local rule check here.
      setSelected(square);
      setTargets([]);

      try {
        const reply = await client.fetchQuery({
          queryKey: ['valid-moves', sessionId, state.fen, square],
          queryFn: () => getValidMoves(sessionId, square),
          staleTime: Infinity,
        });
        if (selectedRef.current === square) {
          const valid = reply.success ? reply.validMoves ?? [] : [];
          if (!valid.length) {
            clearSelection();
          } else {
            setTargets(valid);
          }
        }
      } catch {
        if (selectedRef.current === square) clearSelection();
      }
    },
    [playable, state, selected, targets, setSelected, clearSelection, move, client, sessionId]
  );

  const frames = useMemo(() => gameFrames(state?.moveHistory ?? []), [state?.moveHistory]);

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
    restart: (timeControlMs, incrementMs, difficulty = state?.difficulty ?? 'strong') =>
      restart.mutate({ timeControlMs, incrementMs, difficulty }),
    restarting: restart.isPending,
  };
}
