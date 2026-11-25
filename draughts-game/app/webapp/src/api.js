// Client for the XTC backend (see DraughtsApi.x).
//
// Every @WebService here is @HttpsRequired. In dev, `/api` is relative so Vite's proxy (which
// already targets the HTTPS backend) handles it. In the production build, the page can be
// loaded over plain http (e.g. someone types the bare host), and a relative fetch would silently
// inherit that scheme and get rejected with 403 by the backend - so force https explicitly.
const API_BASE = import.meta.env.DEV ? '/api' : `https://${location.host}/api`;

async function get(path) {
  const res = await fetch(`${API_BASE}/${path}`);
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.message || `Request failed (${res.status})`);
  return body;
}

async function post(path, body) {
  const res = await fetch(`${API_BASE}/${path}`, {
    method: 'POST',
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const reply = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(reply.message || `Request failed (${res.status})`);
  return reply;
}

const session = (id) => encodeURIComponent(id);

/** The game for this session: board, turn, status, message, history. */
export const getGameState = (id) => get(`state/${session(id)}`);

/**
 * Start a new game, replacing the current one. A `level` of 'easy', 'medium' or 'hard' plays the
 * computer (which is White); '' plays a second person at the same screen.
 */
export const newGame = (id, { black, white, level }) => post(`new/${session(id)}`, { black, white, level });

/** Ask the computer to play its move. Does nothing, server-side, if it is not its turn. */
export const computerMove = (id) => post(`computer/${session(id)}`);

/** Every legal move for the player to move, each as a path like "c3-e5-g7". */
export const getMoves = (id) => get(`moves/${session(id)}`);

/** Play a move, given as the path the piece takes. */
export const playMove = (id, path) => post(`move/${session(id)}/${encodeURIComponent(path)}`);

/** This session's scoreboard: the results of every game finished in it. */
export const getScores = (id) => get(`scores/${session(id)}`);

/** Clear it, once its game has ended. */
export const resetScores = (id) => post(`scores/${session(id)}/reset`);

// ----- playing a friend in a room (see OnlineApi.x) -----

const code = (c) => encodeURIComponent(c);

/**
 * Open a room as Black. The reply has the room code to share and your private player id.
 * `timeControlMs` is each player's starting time (0 for no clock); `incrementMs` is added after
 * each of their moves.
 */
export const createRoom = (name, { timeControlMs = 0, incrementMs = 0 } = {}) =>
  post('online/create', { name, timeControlMs, incrementMs });

/** Take the second seat in a room, as White. */
export const joinRoom = (roomCode, name) => post(`online/join/${code(roomCode)}`, { name });

/** The room as this player sees it. Polled to see the other player's moves. */
export const getRoomState = (roomCode, playerId) => get(`online/state/${code(roomCode)}/${code(playerId)}`);

/** Your legal moves in the room, as paths; none unless it is your turn. */
export const getRoomMoves = (roomCode, playerId) => get(`online/moves/${code(roomCode)}/${code(playerId)}`);

export const playRoomMove = (roomCode, playerId, path) =>
  post(`online/move/${code(roomCode)}/${code(playerId)}/${encodeURIComponent(path)}`);

/** A new game in the same room, once one has ended. */
export const rematchRoom = (roomCode, playerId) => post(`online/rematch/${code(roomCode)}/${code(playerId)}`);

/** Leave the room; leaving a game in progress forfeits it. */
export const leaveRoom = (roomCode, playerId) => post(`online/leave/${code(roomCode)}/${code(playerId)}`);

/** The room's scoreboard, across all the games its players have played there. */
export const getRoomScores = (roomCode, playerId) => get(`online/scores/${code(roomCode)}/${code(playerId)}`);

/** Clear it for both players, once the game has ended. */
export const resetRoomScores = (roomCode, playerId) =>
  post(`online/scores/${code(roomCode)}/${code(playerId)}/reset`);
