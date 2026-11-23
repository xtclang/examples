import { useCallback, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { getGameState, getMoves, newGame, playMove } from '../api.js';

const SESSION_KEY = 'draughts-session';

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

const FILES = 'abcdefgh';

/** "c3" -> { row: 5, col: 2 }; row 0 is the top of the board. */
export const rowCol = (square) => ({ row: 8 - Number(square[1]), col: FILES.indexOf(square[0]) });
export const squareName = (row, col) => `${FILES[col]}${8 - row}`;

/** The backend sends 8 row strings, top row first. The board wants a matrix of 'b' 'B' 'w' 'W' or null. */
export function toMatrix(rows = []) {
  return rows.map((row) => [...row].map((ch) => (ch === '.' ? null : ch)));
}

/** The squares a move touched, first and last: "c3-e5-g7" -> ['c3', 'g7']. */
export function moveSquares(lastMove) {
  if (typeof lastMove !== 'string') return [];
  const path = lastMove.split('-');
  return path.length >= 2 ? [path[0], path[path.length - 1]] : [];
}

/**
 * The board with a half-finished multi-jump drawn on it: the piece sits where it has got to, and
 * what it has jumped is gone. Every jump is two squares along a diagonal, so the piece jumped is
 * halfway between.
 */
export function boardAlong(matrix, path) {
  if (path.length < 2) return matrix;
  const next = matrix.map((row) => [...row]);
  const start = rowCol(path[0]);
  const piece = next[start.row][start.col];
  next[start.row][start.col] = null;
  for (let i = 1; i < path.length; i++) {
    const a = rowCol(path[i - 1]);
    const b = rowCol(path[i]);
    next[(a.row + b.row) / 2][(a.col + b.col) / 2] = null;
  }
  const end = rowCol(path[path.length - 1]);
  next[end.row][end.col] = piece;
  return next;
}

/**
 * Plays one game, two people taking turns.
 *
 * TanStack Query owns the game: one query for the state and one for the legal moves. The server
 * is the only thing that decides what a move does -- legality, captures, crowning -- so there is
 * no rule check here. The client only follows paths the server offered: tap a piece, then the
 * squares of its move; a move that is complete (the path matches one the server listed) is sent.
 */
export function usePlay() {
  const [sessionId] = useState(ensureSession);
  const client = useQueryClient();
  const key = useMemo(() => ['game', sessionId], [sessionId]);

  const game = useQuery({
    queryKey: key,
    queryFn: () => getGameState(sessionId),
    refetchOnWindowFocus: true,
  });
  const state = game.data ?? null;
  const ongoing = state?.status === 'Ongoing';

  // Legal moves belong to a position, so the query is keyed by how many moves have been played.
  const moves = useQuery({
    queryKey: ['moves', sessionId, state?.history.length],
    queryFn: () => getMoves(sessionId),
    enabled: Boolean(ongoing),
    staleTime: Infinity,
  });
  const legal = useMemo(() => (moves.data?.success ? moves.data.moves : []), [moves.data]);

  // The squares picked so far: the piece, then each landing square of a multi-jump.
  const [path, setPath] = useState([]);

  const move = useMutation({
    mutationFn: (text) => playMove(sessionId, text),
    onSuccess: (next) => {
      client.setQueryData(key, next);
      if (next.status !== 'Ongoing') client.invalidateQueries({ queryKey: ['scores'] });
    },
    onSettled: () => client.invalidateQueries({ queryKey: key }),
  });

  const restart = useMutation({
    mutationFn: ({ black, white }) => newGame(sessionId, black, white),
    onSuccess: (next) => {
      setPath([]);
      client.setQueryData(key, next);
    },
  });

  const playable = Boolean(ongoing) && !move.isPending && moves.isSuccess;

  // Where the picked piece may go next: the square after `path` in every move that starts with it.
  const targets = useMemo(() => {
    if (!path.length) return [];
    const next = new Set();
    for (const text of legal) {
      const squares = text.split('-');
      if (squares.length > path.length && path.every((sq, i) => squares[i] === sq)) {
        next.add(squares[path.length]);
      }
    }
    return [...next];
  }, [path, legal]);

  const movable = useMemo(() => new Set(legal.map((text) => text.split('-')[0])), [legal]);

  /** Tap a square: pick up a piece, step on to a landing square, or put the piece back. */
  const touch = useCallback(
    (square) => {
      if (!playable) return;

      if (path.length && square === path[0]) {
        setPath([]);
        return;
      }
      if (path.length && targets.includes(square)) {
        const next = [...path, square];
        const text = next.join('-');
        if (legal.includes(text)) {
          setPath([]);
          move.mutate(text);
        } else {
          setPath(next); // a multi-jump with more to come
        }
        return;
      }
      // Choosing another piece is only allowed before a jump has begun.
      if (path.length <= 1 && movable.has(square)) {
        setPath([square]);
        return;
      }
      if (path.length <= 1) setPath([]);
    },
    [playable, path, targets, legal, movable, move]
  );

  return {
    sessionId,
    state,
    loading: game.isPending,
    error: game.error?.message ?? move.error?.message ?? restart.error?.message ?? '',
    playable,
    path,
    selected: path.length ? path[path.length - 1] : null,
    targets,
    movable,
    touch,
    restart: (black, white) => restart.mutate({ black, white }),
    restarting: restart.isPending,
  };
}
