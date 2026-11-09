// Client for the XTC backend. Two groups of endpoints:
//   /api/chesscom/... → the chess.com Published-Data proxy (see ChessComApi.x)
//   /api/engine/...   → the Stockfish Online proxy (see EngineApi.x), which is also the
//                       engine the computer opponent plays by
//
// Every @WebService here is @HttpsRequired. In dev, `/api` is relative so Vite's proxy (which
// already targets the HTTPS backend) handles it. In the production build, the page can be
// loaded over plain http (e.g. someone types the bare host), and a relative fetch would silently
// inherit that scheme and get rejected with 403 by the backend - so force https explicitly.
const API_BASE = import.meta.env.DEV ? '/api' : `https://${location.host}/api`;

async function get(path, params) {
  const query = params ? `?${new URLSearchParams(params)}` : '';
  const res = await fetch(`${API_BASE}/${path}${query}`);
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

// ----- playing a game against the computer (see ChessApi.x) -----

const session = (id) => encodeURIComponent(id);
const square = (name) => encodeURIComponent(name);

export const getGameState = (id) => get(`state/${session(id)}`);
export const resetGame = (id, timeControlMs = 0, incrementMs = 0, difficulty = 'strong') =>
  post(`reset/${session(id)}`, { timeControlMs, incrementMs, difficulty });
export const playMove = (id, from, to) => post(`move/${session(id)}/${square(from)}/${square(to)}`);
export const getValidMoves = (id, from) => get(`validmoves/${session(id)}/${square(from)}`);

// ----- reviewing games from chess.com (see ChessComApi.x) -----

export const getPlayer = (name) => get(`chesscom/player/${encodeURIComponent(name)}`);
export const getArchives = (name) => get(`chesscom/archives/${encodeURIComponent(name)}`);
export const getDailyPuzzle = () => get('chesscom/puzzle');

// archiveUrl looks like https://api.chess.com/pub/player/{name}/games/{yyyy}/{mm}
export async function getGamesFromArchive(name, archiveUrl) {
  const [, year, month] = archiveUrl.match(/\/games\/(\d{4})\/(\d{2})$/) ?? [];
  if (!year) throw new Error('Unexpected archive URL');
  return (await get(`chesscom/games/${encodeURIComponent(name)}/${year}/${month}`)).games ?? [];
}




/**
 * Engine evaluation of one position, via the server's `/api/engine` proxy (see EngineApi.x). The
 * browser never calls Stockfish directly: the upstream URL, user agent and depth limits all live
 * server-side, same as the chess.com endpoints above.
 *
 * `evaluation` is in pawns from White's point of view and is null in a forced mate, where
 * `mate` carries the distance to mate for the side to move instead.
 */
export async function analysePosition(fen, depth = 11) {
  const body = await get('engine/analyse', { fen, depth });
  if (!body.success) throw new Error(body.message || 'Engine unavailable');
  return body;
}

// ----- playing online with a friend (see OnlineChessApi.x) -----

export const createRoom = (timeControlMs = 0, incrementMs = 0) =>
  post('online/create', timeControlMs > 0 ? { timeControlMs, incrementMs } : undefined);
export const joinRoom = (roomCode) => post(`online/join/${encodeURIComponent(roomCode)}`);
export const getRoomState = (roomCode, playerId) =>
  get(`online/state/${encodeURIComponent(roomCode)}/${encodeURIComponent(playerId)}`);
export const playRoomMove = (roomCode, playerId, from, to) =>
  post(`online/move/${encodeURIComponent(roomCode)}/${encodeURIComponent(playerId)}/${square(from)}/${square(to)}`);
export const resetRoom = (roomCode, playerId) =>
  post(`online/reset/${encodeURIComponent(roomCode)}/${encodeURIComponent(playerId)}`);
export const leaveRoom = (roomCode, playerId) =>
  post(`online/leave/${encodeURIComponent(roomCode)}/${encodeURIComponent(playerId)}`);
export const getRoomValidMoves = (roomCode, playerId, from) =>
  get(`online/validmoves/${encodeURIComponent(roomCode)}/${encodeURIComponent(playerId)}/${square(from)}`);
