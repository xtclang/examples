import { useCallback, useMemo } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  createRoom,
  getRoomMoves,
  getRoomState,
  joinRoom,
  leaveRoom,
  playRoomMove,
  rematchRoom,
} from '../api.js';
import { usePersistentState } from '../components/ui.jsx';
import { useSelection } from './play.js';

/** How often to ask whether the other player has moved (or joined). */
const POLL_MS = 1500;
/** Slower, once the game is over and there is little to see. */
const IDLE_POLL_MS = 5000;

/**
 * Plays a friend in a room.
 *
 * The seat -- the room code and this browser's private player id -- is kept in local storage, so
 * reloading the page returns you to the same seat in the same room. The room's state is polled:
 * the server is the only thing that knows the other player's moves, and it decides every rule, so
 * this only follows the move paths the server offers, exactly as the single-player game does.
 *
 * `active` is whether the Room page is showing; polling stops when it is not.
 */
export function useRoom(active = true) {
  const client = useQueryClient();
  const [seat, setSeat] = usePersistentState('draughts-seat', null);
  const key = useMemo(() => ['room', seat?.code, seat?.playerId], [seat]);

  const room = useQuery({
    queryKey: key,
    queryFn: () => getRoomState(seat.code, seat.playerId),
    enabled: Boolean(seat) && active,
    refetchInterval: (query) => {
      const data = query.state.data;
      if (!data?.success) return false;
      return data.status === 'Ongoing' || data.waiting ? POLL_MS : IDLE_POLL_MS;
    },
    refetchOnWindowFocus: true,
  });
  const state = room.data?.success ? room.data : null;

  // A room that no longer exists (or a seat that is not ours) is forgotten.
  const gone = Boolean(seat) && room.data && !room.data.success && !room.data.board?.length;

  const legalQuery = useQuery({
    queryKey: ['room-moves', seat?.code, seat?.playerId, state?.history.length],
    queryFn: () => getRoomMoves(seat.code, seat.playerId),
    enabled: Boolean(state?.yourTurn) && state?.status === 'Ongoing',
    staleTime: Infinity,
  });
  const legal = useMemo(() => (legalQuery.data?.success ? legalQuery.data.moves : []), [legalQuery.data]);

  const accept = useCallback(
    (next) => {
      if (next.success) {
        client.setQueryData(key, next);
        if (next.status !== 'Ongoing') client.invalidateQueries({ queryKey: ['scores'] });
      }
      return next;
    },
    [client, key]
  );

  const move = useMutation({
    mutationFn: (text) => playRoomMove(seat.code, seat.playerId, text),
    onSuccess: (next) => {
      accept(next);
      selection.setPath([]); // with the new state, in the same render
    },
    onError: () => selection.setPath([]),
    onSettled: () => client.invalidateQueries({ queryKey: key }),
  });

  const rematch = useMutation({
    mutationFn: () => rematchRoom(seat.code, seat.playerId),
    onSuccess: accept,
  });

  const leave = useMutation({
    mutationFn: () => leaveRoom(seat.code, seat.playerId),
    onSuccess: (next) => {
      if (next.status && next.status !== 'Ongoing') client.invalidateQueries({ queryKey: ['scores'] });
      setSeat(null);
    },
  });

  /** Open a room, or join one by its code; either way, this browser takes the seat it is given. */
  const enter = useMutation({
    mutationFn: ({ code, name, timeControl }) =>
      code ? joinRoom(code, name) : createRoom(name, { timeControlMs: timeControl?.ms, incrementMs: timeControl?.inc }),
    onSuccess: (next) => {
      if (next.success) {
        client.setQueryData(['room', next.roomCode, next.playerId], next);
        setSeat({ code: next.roomCode, playerId: next.playerId });
      }
    },
  });

  const playable =
    Boolean(state?.yourTurn) && state?.status === 'Ongoing' && !move.isPending && legalQuery.isSuccess;
  const selection = useSelection({ legal, playable, submit: (text) => move.mutate(text) });

  // Why the last thing failed, from the network or from the server's own refusal.
  const refused = [enter.data, move.data, rematch.data].find((reply) => reply && !reply.success);
  const error =
    room.error?.message ??
    enter.error?.message ??
    move.error?.message ??
    rematch.error?.message ??
    refused?.message ??
    (gone ? room.data.message : '') ??
    '';

  return {
    seat,
    state,
    gone,
    forget: () => setSeat(null),
    loading: Boolean(seat) && room.isPending,
    error,
    playable,
    selection,
    enter: (code, name, timeControl) => enter.mutate({ code, name, timeControl }),
    entering: enter.isPending,
    rematch: () => rematch.mutate(),
    rematching: rematch.isPending,
    leave: () => leave.mutate(),
    leaving: leave.isPending,
  };
}
