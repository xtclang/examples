import { useEffect, useState } from 'react';
import Play from './components/Play.jsx';
import Room from './components/Room.jsx';
import ErrorBoundary from './components/ErrorBoundary.jsx';
import Scoreboard, { NoScoreboard } from './components/Scoreboard.jsx';
import { getRoomScores, getScores, resetRoomScores, resetScores } from './api.js';
import { PiecePair } from './components/Piece.jsx';
import { usePersistentState } from './components/ui.jsx';
import { usePlay } from './lib/play.js';
import { useRoom } from './lib/room.js';
import { play as playSound, setSoundEnabled } from './lib/sound.js';

/** The theme lives on <html> as a class; index.html applies the saved one before first paint. */
function useTheme() {
  const [theme, setTheme] = usePersistentState('theme', 'dark');
  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
  }, [theme]);
  return [theme, () => setTheme((t) => (t === 'dark' ? 'light' : 'dark'))];
}

/** Sound on or off, remembered. Turning it on plays a blip so you can hear that it is. */
function useSoundSwitch() {
  const [on, setOn] = usePersistentState('sound', true);
  useEffect(() => setSoundEnabled(on), [on]);
  return [
    on,
    () => {
      setOn(!on);
      if (!on) {
        setSoundEnabled(true);
        playSound('move');
      }
    },
  ];
}

const TITLES = { play: 'Draughts', room: 'Play a friend' };

export default function App() {
  const [view, setView] = usePersistentState('view', 'play');
  const [theme, toggleTheme] = useTheme();
  const [soundOn, toggleSound] = useSoundSwitch();

  // A friend's invitation link (?room=CODE) lands on the Room page with the code filled in.
  const [joinCode] = useState(() => new URLSearchParams(window.location.search).get('room'));
  useEffect(() => {
    if (joinCode) setView('room');
  }, [joinCode, setView]);

  const play = usePlay();
  const room = useRoom(view === 'room');

  // Once in the room, the invitation is used up: drop it from the address.
  useEffect(() => {
    if (joinCode && room.seat) window.history.replaceState(null, '', window.location.pathname);
  }, [joinCode, room.seat]);

  const playing = view === 'play';

  // Each game keeps its own scoreboard: this session's, or the room's. It can be reset once the
  // game in front of the players has ended (or before it has begun).
  const game = playing ? play.state : room.state;
  const idle = !game || game.status !== 'Ongoing' || game.history.length === 0;
  const version = game ? `${game.status}:${game.history.length}` : 'none';

  return (
    <div className="shell">
      <header className="site-head">
        <div className="head-left">
          <span className="brand">
            <PiecePair size={26} />
          </span>
        </div>
        <div className="head-center">
          <h1 className="page-title">{TITLES[view]}</h1>
        </div>
        <nav className="head-right" aria-label="Pages">
          <button className={`btn btn-nav${playing ? ' on' : ''}`} onClick={() => setView('play')}>
            Play
          </button>
          <button className={`btn btn-nav${!playing ? ' on' : ''}`} onClick={() => setView('room')}>
            Room
          </button>
          <button
            className="icon-btn"
            onClick={toggleSound}
            aria-pressed={soundOn}
            aria-label={soundOn ? 'Mute sounds' : 'Turn sounds on'}
            title={soundOn ? 'Mute sounds' : 'Turn sounds on'}
          >
            <svg viewBox="0 0 16 16" width="15" height="15" aria-hidden="true">
              <path d="M2 6h2.6L8 3v10L4.6 10H2z" fill="currentColor" />
              {soundOn ? (
                <path
                  d="M10.4 5.6a3.6 3.6 0 0 1 0 4.8M12.2 3.8a6.2 6.2 0 0 1 0 8.4"
                  fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"
                />
              ) : (
                <path d="M10.5 6l3.5 4M14 6l-3.5 4" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
              )}
            </svg>
          </button>
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
          <ErrorBoundary resetKey={view}>
            {playing ? <Play play={play} /> : <Room room={room} joinCode={joinCode} />}
          </ErrorBoundary>
        </section>
        <section className="pane analysis-pane">
          <div className="panel">
            {playing ? (
              <Scoreboard
                scope="This game"
                id={`play:${play.sessionId}`}
                load={() => getScores(play.sessionId)}
                reset={() => resetScores(play.sessionId)}
                canReset={idle}
                version={version}
              />
            ) : room.seat ? (
              <Scoreboard
                scope={`Room ${room.seat.code}`}
                id={`room:${room.seat.code}`}
                load={() => getRoomScores(room.seat.code, room.seat.playerId)}
                reset={() => resetRoomScores(room.seat.code, room.seat.playerId)}
                canReset={idle}
                version={version}
                poll={5000}
              />
            ) : (
              <NoScoreboard />
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
