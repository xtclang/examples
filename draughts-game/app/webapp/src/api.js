// Client for the XTC backend (see DraughtsApi.x and ScoresApi.x).
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

/** Start a new game, replacing the current one. */
export const newGame = (id, black, white) => post(`new/${session(id)}`, { black, white });

/** Every legal move for the player to move, each as a path like "c3-e5-g7". */
export const getMoves = (id) => get(`moves/${session(id)}`);

/** Play a move, given as the path the piece takes. */
export const playMove = (id, path) => post(`move/${session(id)}/${encodeURIComponent(path)}`);

/** Today's scoreboard. */
export const getScores = () => get('scores');
