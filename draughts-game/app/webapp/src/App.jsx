import { useEffect } from 'react';
import Play from './components/Play.jsx';
import Scoreboard from './components/Scoreboard.jsx';
import { usePersistentState } from './components/ui.jsx';
import { usePlay } from './lib/play.js';

/** The theme lives on <html> as a class; index.html applies the saved one before first paint. */
function useTheme() {
  const [theme, setTheme] = usePersistentState('theme', 'dark');
  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
  }, [theme]);
  return [theme, () => setTheme((t) => (t === 'dark' ? 'light' : 'dark'))];
}

function Rules() {
  return (
    <section className="rules" aria-label="How to play">
      <h2>How to play</h2>
      <ul>
        <li>Black moves first. Take turns at the same screen.</li>
        <li>Men move one square diagonally forward; kings move both ways.</li>
        <li>Jump an enemy piece by landing on the empty square just beyond it.</li>
        <li>Captures are compulsory, and a piece must keep jumping while it can.</li>
        <li>A man reaching the far row becomes a king, and its move ends there.</li>
        <li>If you cannot move, you lose. 40 moves each with no capture or man moved is a draw.</li>
      </ul>
    </section>
  );
}

export default function App() {
  const play = usePlay();
  const [theme, toggleTheme] = useTheme();

  return (
    <div className="shell">
      <header className="site-head">
        <div className="head-left" />
        <div className="head-center">
          <h1 className="page-title">Draughts</h1>
        </div>
        <nav className="head-right" aria-label="Page">
          <button
            className="icon-btn theme-toggle"
            onClick={toggleTheme}
            aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
            title={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
          >
            {theme === 'dark' ? (
              <svg viewBox="0 0 16 16" width="15" height="15" aria-hidden="true">
                <path
                  d="M8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"
                  stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"
                />
                <circle cx="8" cy="8" r="3" fill="none" stroke="currentColor" strokeWidth="1.3" />
              </svg>
            ) : (
              <svg viewBox="0 0 16 16" width="15" height="15" aria-hidden="true">
                <path d="M13.5 9.7A5.8 5.8 0 0 1 6.3 2.5a5.8 5.8 0 1 0 7.2 7.2z" fill="currentColor" />
              </svg>
            )}
          </button>
        </nav>
      </header>

      <main className="split">
        <section className="pane board-pane">
          <Play play={play} />
        </section>
        <section className="pane analysis-pane">
          <div className="panel">
            <Scoreboard />
            <Rules />
          </div>
        </section>
      </main>
    </div>
  );
}
