import { useEffect, useState } from 'react';
import Replay from './components/Replay.jsx';
import Analysis from './components/Analysis.jsx';
import { useGame } from './lib/analyse.js';
import { getPlayer, getArchives, getGamesFromArchive, getDailyPuzzle } from './api.js';

const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

function describe(game) {
  return `${game.white.username} vs ${game.black.username} · ${game.time_class} · ${game.white.result}/${game.black.result}`;
}

export default function App() {
  const [username, setUsername] = useState('');
  const [status, setStatus] = useState('');
  const [profile, setProfile] = useState(null);
  const [games, setGames] = useState([]);
  const [selected, setSelected] = useState(null);
  const [puzzle, setPuzzle] = useState(null);
  const [view, setView] = useState({ fen: START_FEN, title: 'Starting position' });
  const [ply, setPly] = useState(0);

  const game = useGame(view);

  // A new game or puzzle starts at its first frame.
  useEffect(() => setPly(0), [view]);

  async function run(label, fn) {
    setStatus(label);
    try {
      await fn();
      setStatus('');
    } catch (e) {
      setStatus(e.message);
    }
  }

  const loadPlayer = (e) => {
    e.preventDefault();
    const name = username.trim();
    if (!name) return;
    run('Loading player…', async () => {
      const [p, archives] = await Promise.all([getPlayer(name), getArchives(name)]);
      const latest = archives.archives?.at(-1);
      setProfile(p);
      setGames(latest ? (await getGamesFromArchive(name, latest)).reverse() : []);
      setSelected(null);
    });
  };

  const pick = (g) => {
    setSelected(g);
    setPuzzle(null);
    setView({
      pgn: g.pgn,
      title: describe(g),
      flipped: g.black.username.toLowerCase() === profile.username.toLowerCase(),
      names: { w: g.white.username, b: g.black.username },
    });
  };

  const loadPuzzle = () =>
    run('Loading puzzle…', async () => {
      const p = await getDailyPuzzle();
      setPuzzle(p);
      setSelected(null);
      setView({ fen: p.fen, title: `Daily puzzle · ${p.title}` });
    });

  return (
    <div className="shell">
      <header className="topbar">
        <h1>Chess Playground</h1>
        <form onSubmit={loadPlayer}>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="chess.com username"
            aria-label="chess.com username"
          />
          <button type="submit">Load games</button>
        </form>
        <button onClick={loadPuzzle}>Daily puzzle</button>
        {games.length > 0 && (
          <label className="game-picker">
            <span className="sr-only">Game</span>
            <select
              value={selected ? selected.url : ''}
              onChange={(e) => pick(games.find((g) => g.url === e.target.value))}
            >
              <option value="" disabled>
                {games.length} games this month…
              </option>
              {games.map((g) => (
                <option key={g.url} value={g.url}>
                  {describe(g)}
                </option>
              ))}
            </select>
          </label>
        )}
        {profile && <span className="who">{profile.username}</span>}
        {status && <span className="status">{status}</span>}
      </header>

      <main className="split">
        <section className="pane board-pane">
          <Replay
            positions={game.positions}
            moves={game.moves}
            error={game.error}
            title={view.title}
            flipped={view.flipped}
            ply={ply}
            setPly={setPly}
          />
          {puzzle && (
            <a className="outlink" href={puzzle.url} target="_blank" rel="noreferrer">
              Solve on chess.com ↗
            </a>
          )}
        </section>

        <section className="pane analysis-pane">
          <Analysis
            pgn={view.pgn}
            fen={view.fen}
            positions={game.positions}
            ply={ply}
            setPly={setPly}
            names={view.names}
          />
        </section>
      </main>
    </div>
  );
}
