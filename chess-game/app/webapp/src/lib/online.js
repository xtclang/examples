import { useCallback, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  createRoom,
  getRoomState,
  getRoomValidMoves,
  joinRoom,
  leaveRoom,
  playRoomMove,
  resetRoom,
} from '../api.js';
import { replayHistory } from './analyse.js';
import { toMatrix } from './play.js';

const ROOM_KEY = 'chess-room';

/** The room this browser is seated in, if any: survives a reload so a refresh re-enters the
 *  same seat instead of losing the game. */
function readRoom() {
  try {
    const stored = JSON.parse(localStorage.getItem(ROOM_KEY) ?? 'null');
    return stored?.roomCode && stored?.playerId ? stored : null;
  } catch {
    return null;
  }
}

function writeRoom(room) {
  try {
    if (room) localStorage.setItem(ROOM_KEY, JSON.stringify(room));
    else localStorage.removeItem(ROOM_KEY);
  } catch {
    // Private window or storage blocked: the seat lasts for this visit only.
  }
}

/** Moves one piece in a board matrix without consulting chess rules -- the server is the judge;
 *  this only has to look right for the instant before its reply lands. */
function movePiece(board, from, to) {
  const files = 'abcdefgh';
  const at = (sq) => ({ row: 8 - Number(sq[1]), col: files.indexOf(sq[0]) });
  const f = at(from);
  const t = at(to);
  const piece = board[f.row]?.[f.col];
  if (!piece) return board;
  const promoting = piece.type === 'p' && (t.row === 0 || t.row === 7);
  const next = board.map((row) => row.slice());
  next[t.row][t.col] = promoting ? { type: 'q', color: piece.color } : piece;
  next[f.row][f.col] = null;
  return next;
}

function toRows(board) {
  return board.map((rank) =>
    rank.map((cell) => (cell ? (cell.color === 'w' ? cell.type.toUpperCase() : cell.type) : '.')).join('')
  );
}

/** How often to ask the server for the opponent's move. */
const POLL_MS = 1500;

/**
 * Plays one game in a shared room.
 *
 * The seat (room code + player id) is kept in local storage, so reloading the page returns to
 * the same room as the same player rather than starting a new one. The opponent's color, whose
 * turn it is, and whether the room is still waiting for a second player all come straight from
 * the server's response -- unlike the single-player game, nothing here has to work that out.
 *
 * TanStack Query owns the game the same way `usePlay` does: one query per seat, polled while the
 * game is ongoing, moves applied optimistically and rolled back if the server refuses them.
 */
export function useOnlineGame() {
  const [room, setRoomState] = useState(readRoom);
  const client = useQueryClient();
  const key = useMemo(() => ['online-game', room?.roomCode, room?.playerId], [room]);
  const movingRef = useRef(false);

  const setRoom = useCallback((next) => {
    writeRoom(next);
    setRoomState(next);
  }, []);

  const game = useQuery({
    queryKey: key,
    queryFn: () => getRoomState(room.roomCode, room.playerId),
    enabled: Boolean(room),
    refetchInterval: (query) =>
      !movingRef.current && query.state.data?.status === 'Ongoing' ? POLL_MS : false,
    refetchOnWindowFocus: true,
  });
  const state = room ? (game.data ?? null) : null;

  const create = useMutation({
    mutationFn: ({ timeControlMs = 0, incrementMs = 0 } = {}) => createRoom(timeControlMs, incrementMs),
    onSuccess: (created) => setRoom({ roomCode: created.roomCode, playerId: created.playerId }),
  });

  const join = useMutation({
    mutationFn: (roomCode) => joinRoom(roomCode.trim().toUpperCase()),
    onSuccess: (next) => {
      if (!next.playerId) throw new Error(next.message || 'Could not join that room.');
      setRoom({ roomCode: next.roomCode, playerId: next.playerId });
      client.setQueryData(['online-game', next.roomCode, next.playerId], next);
    },
  });

  const leave = useMutation({
    mutationFn: () => leaveRoom(room.roomCode, room.playerId),
    onSettled: () => setRoom(null),
  });

  const [selected, setSelectedState] = useState(null);
  const [targets, setTargets] = useState([]);
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
    mutationFn: ({ from, to }) => playRoomMove(room.roomCode, room.playerId, from, to),
    onMutate: async ({ from, to }) => {
      movingRef.current = true;
      await client.cancelQueries({ queryKey: key });
      const previous = client.getQueryData(key);
      if (previous?.board) {
        client.setQueryData(key, {
          ...previous,
          board: toRows(movePiece(toMatrix(previous.board), from, to)),
          turn: previous.playerColor,
          lastMove: `${from}${to}`,
          isYourTurn: false,
        });
      }
      return { previous };
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
    mutationFn: () => resetRoom(room.roomCode, room.playerId),
    onSuccess: (next) => {
      clearSelection();
      client.setQueryData(key, next);
    },
  });

  const playable = state?.status === 'Ongoing' && state?.isYourTurn && !move.isPending;

  /** Click a square: pick up a piece, put it down, or switch to another piece. Targets come from
   *  the server -- there is no local FEN to preview candidate moves from, unlike single-player. */
  const touch = useCallback(
    async (square) => {
      if (!playable || !room) return;

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

      setSelected(square);
      setTargets([]);
      try {
        const reply = await getRoomValidMoves(room.roomCode, room.playerId, square);
        if (selectedRef.current === square) {
          setTargets(reply.success ? reply.validMoves ?? [] : []);
        }
      } catch {
        if (selectedRef.current === square) clearSelection();
      }
    },
    [playable, room, selected, targets, setSelected, clearSelection, move]
  );

  const frames = useMemo(
    () => replayHistory(state?.moveHistory ?? [], state?.fen ?? null),
    [state?.moveHistory, state?.fen]
  );

  return {
    room,
    state,
    frames,
    loading: Boolean(room) && game.isPending,
    error: game.error?.message ?? move.error?.message ?? join.error?.message ?? create.error?.message ?? '',
    playable,
    selected,
    targets,
    touch,
    clearSelection,
    create: (timeControlMs, incrementMs) => create.mutate({ timeControlMs, incrementMs }),
    creating: create.isPending,
    join: (roomCode) => join.mutate(roomCode),
    joining: join.isPending,
    leave: () => leave.mutate(),
    leaving: leave.isPending,
    restart: () => restart.mutate(),
    restarting: restart.isPending,
  };
}
