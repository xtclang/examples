// Client for the XTC backend. Two groups of endpoints:
//   /api/chesscom/... → the chess.com Published-Data proxy (see ChessComApi.x)
//   /api/engine/...   → the Stockfish Online proxy (see EngineApi.x), which is also the
//                       engine the computer opponent plays by
async function get(path, params) {
  const query = params ? `?${new URLSearchParams(params)}` : '';
  const res = await fetch(`/api/${path}${query}`);
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.message || `Request failed (${res.status})`);
  return body;
}

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
 * Engine evaluation of one position.
 *
 * `evaluation` is in pawns from White's point of view and is null in a forced mate, where
 * `mate` carries the distance to mate for the side to move instead.
 */
export async function analysePosition(fen, depth = 11) {
  const body = await get('engine/analyse', { fen, depth });
  if (!body.success) throw new Error(body.message || 'Engine unavailable');
  return body;
}
