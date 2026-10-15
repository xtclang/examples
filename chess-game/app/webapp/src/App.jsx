import { lazy, Suspense, useEffect, useState } from 'react';
import Play from './components/Play.jsx';
import Replay from './components/Replay.jsx';
import { Skeleton, usePersistentState } from './components/ui.jsx';
import { START_FEN, useGame } from './lib/analyse.js';
import { usePlay } from './lib/play.js';
import { holdEngine } from './lib/engine.js';
import { getArchives, getDailyPuzzle, getGamesFromArchive, getPlayer } from './api.js';

// The charts (and d3 beneath them) and the guide load after the board, so play starts at once.
const MetricsPanel = lazy(() => import('./components/MetricsPanel.jsx').then((m) => ({ default: m.MetricsPanel })));
const Guide = lazy(() => import('./components/Guide.jsx'));

function PanelSkeleton() {
  return (
    <div className="metrics" aria-busy="true">
      <Skeleton width="8rem" height="1.4rem" />
      <Skeleton width="100%" height="9rem" radius={16} />
      <Skeleton width="100%" height="5rem" radius={16} />
      <Skeleton width="100%" height="14rem" radius={16} />
    </div>
  );
}

const describe = (g) =>
  `${g.white.username} vs ${g.black.username} · ${g.time_class} · ${g.white.result}/${g.black.result}`;

const TITLES = { play: 'Play', review: 'Review', guide: 'Guide' };

/** The theme lives on <html> as a class; index.html applies the saved one before first paint. */
function useTheme() {
  const [theme, setTheme] = usePersistentState('theme', 'dark');
  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
  }, [theme]);
  return [theme, () => setTheme((t) => (t === 'dark' ? 'light' : 'dark'))];
}

function Footer({ theme, onToggleTheme }) {
  return (
    <footer className="site-foot">
      <button className="btn" onClick={onToggleTheme} aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}>
        {theme === 'dark' ? 'light' : 'dark'}
      </button>
      <p className="credits">
        Built with <a href="https://github.com/xtclang/xvm" target="_blank" rel="noreferrer">XTC</a>
        <span aria-hidden="true">·</span>
        Engine by <a href="https://stockfish.online" target="_blank" rel="noreferrer">Stockfish Online</a>
        <span aria-hidden="true">·</span>
        Development build
      </p>
    </footer>
  );
}

export default function App() {
  const [view, setView] = usePersistentState('view', 'play');
  const [insightsOpen, setInsightsOpen] = usePersistentState('insights-open', true);
  const [theme, toggleTheme] = useTheme();

  // Playing against the engine
  const play = usePlay();
  const [viewing, setViewing] = useState(null);
  const liveIndex = Math.max(0, play.frames.positions.length - 1);
  useEffect(() => setViewing(null), [play.state?.moveHistory?.length]);

  // Leave the engine to the computer while it is choosing its move; see holdEngine.
  useEffect(() => holdEngine(play.thinking), [play.thinking]);

  // Reviewing games from chess.com
  const [username, setUsername] = useState('');
  const [status, setStatus] = useState('');
  const [profile, setProfile] = useState(null);
  const [games, setGames] = useState([]);
  const [selected, setSelected] = useState(null);
  const [source, setSource] = useState({ fen: START_FEN, title: 'Starting position' });
  const [ply, setPly] = useState(0);
  const reviewed = useGame(source);
  useEffect(() => setPly(0), [source]);

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
    run('loading…', async () => {
      const [p, archives] = await Promise.all([getPlayer(name), getArchives(name)]);
      const latest = archives.archives?.at(-1);
      setProfile(p);
      setGames(latest ? (await getGamesFromArchive(name, latest)).reverse() : []);
      setSelected(null);
    });
  };

  const pick = (g) => {
    setSelected(g);
    setSource({
      pgn: g.pgn,
      title: describe(g),
      flipped: g.black.username.toLowerCase() === profile.username.toLowerCase(),
      names: { w: g.white.username, b: g.black.username },
    });
  };

  const loadPuzzle = () =>
    run('loading…', async () => {
      const p = await getDailyPuzzle();
      setSelected(null);
      setSource({ fen: p.fen, title: `Daily puzzle · ${p.title}` });
    });

  const playing = view === 'play';
  const panel = playing
    ? {
        mode: 'play',
        positions: play.frames.positions,
        moves: play.frames.moves,
        current: viewing ?? liveIndex,
        onSeek: (k) => setViewing(k >= liveIndex ? null : k),
      }
    : {
        mode: 'review',
        positions: reviewed.positions,
        moves: reviewed.moves,
        current: Math.min(ply, Math.max(0, reviewed.positions.length - 1)),
        names: source.names,
        onSeek: setPly,
      };

  const navTo = (target) => (
    <button key={target} className={`btn btn-nav${view === target ? ' on' : ''}`} onClick={() => setView(target)}>
      {target === 'guide' ? 'Guide →' : target}
    </button>
  );

  return (
    <div className="shell">
      <header className="site-head">
        <div className="head-left">
          {!playing && (
            <button className="btn btn-nav" onClick={() => setView('play')}>← Play</button>
          )}
        </div>
        <div className="head-center">
          <h1 className="page-title">{TITLES[view]}</h1>
        </div>
        <nav className="head-right" aria-label="Pages">
          {['review', 'guide'].filter((v) => v !== view).map(navTo)}
          {!playing && (
            <button className="btn btn-nav" onClick={toggleTheme}>
              {theme === 'dark' ? 'light' : 'dark'}
            </button>
          )}
        </nav>
      </header>

      {view === 'review' && (
        <div className="toolbar">
          <form className="search" onSubmit={loadPlayer}>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="chess.com username"
              aria-label="chess.com username"
            />
            <button className="chip" type="submit">load games</button>
          </form>
          <button className="chip" onClick={loadPuzzle}>daily puzzle</button>
          {games.length > 0 && (
            <select
              className="game-picker"
              aria-label="Game"
              value={selected ? selected.url : ''}
              onChange={(e) => pick(games.find((g) => g.url === e.target.value))}
            >
              <option value="" disabled>{games.length} games this month…</option>
              {games.map((g) => (
                <option key={g.url} value={g.url}>{describe(g)}</option>
              ))}
            </select>
          )}
          {status && <span className="toolbar-status">{status}</span>}
        </div>
      )}

      {view === 'guide' ? (
        <main className="page">
          <Suspense fallback={<Skeleton width="100%" height="12rem" radius={16} />}>
            <Guide onPlay={() => setView('play')} />
          </Suspense>
          <Footer theme={theme} onToggleTheme={toggleTheme} />
        </main>
      ) : (
        <main className={insightsOpen ? 'split' : 'split split-focus'}>
          <section className="pane board-pane">
            {playing ? (
              <Play play={play} viewing={viewing} onView={(k) => setViewing(k === null || k >= liveIndex ? null : k)} />
            ) : (
              <Replay
                positions={reviewed.positions}
                moves={reviewed.moves}
                error={reviewed.error}
                title={source.title}
                flipped={source.flipped}
                ply={ply}
                setPly={setPly}
              />
            )}
            <Footer theme={theme} onToggleTheme={toggleTheme} />
            {!insightsOpen && (
              <button className="btn btn-solid insights-reopen" onClick={() => setInsightsOpen(true)}>
                ← Insights
              </button>
            )}
          </section>
          {insightsOpen && (
            <section className="pane analysis-pane">
              <div className="panel">
                <Suspense fallback={<PanelSkeleton />}>
                  <MetricsPanel {...panel} onCollapse={() => setInsightsOpen(false)} onGuide={() => setView('guide')} />
                </Suspense>
              </div>
            </section>
          )}
        </main>
      )}

    </div>
  );
}
