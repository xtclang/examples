import { useEffect, useRef, useState } from 'react';
import GameView, { GameSkeleton } from './GameView.jsx';
import { DEFAULT_SETUP, GameOverModal, NewGameModal } from './Modals.jsx';
import { usePersistentState } from './ui.jsx';

/** The single-player game: against the computer, or two people at one screen. */
export default function Play({ play }) {
  const { state, error, playable, thinking, restart, restarting } = play;

  // What this browser chose last time, so it is filled in next time.
  const [saved, setSaved] = usePersistentState('draughts-setup', null);
  const [asking, setAsking] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const lastStatus = useRef(state?.status);

  const moveCount = state?.history.length ?? 0;
  const over = state ? state.status !== 'Ongoing' : false;

  useEffect(() => {
    if (state?.status !== lastStatus.current) setDismissed(false);
    lastStatus.current = state?.status;
  }, [state?.status]);

  // First visit, nothing played yet: ask who is playing before the first move.
  const [greeted, setGreeted] = useState(false);
  useEffect(() => {
    if (state && !greeted) {
      setGreeted(true);
      if (!saved && moveCount === 0) setAsking(true);
    }
  }, [state, greeted, saved, moveCount]);

  if (!state) return error ? <p className="error">{error}</p> : <GameSkeleton />;

  const vsComputer = state.level !== '';
  const start = (setup) => {
    setSaved(setup);
    setAsking(false);
    setDismissed(true);
    restart({
      black: setup.black,
      white: setup.white,
      level: setup.mode === '1' ? setup.level : '',
    });
  };
  const rematch = () =>
    start(
      saved ?? {
        ...DEFAULT_SETUP,
        mode: vsComputer ? '1' : '2',
        black: state.blackName,
        white: state.whiteName,
        level: state.level || 'medium',
      }
    );

  return (
    <div className="game-root">
      {asking && (
        <NewGameModal
          initial={saved ?? DEFAULT_SETUP}
          onStart={start}
          onCancel={moveCount === 0 && !saved ? null : () => setAsking(false)}
          busy={restarting}
        />
      )}
      {over && !dismissed && !asking && (
        <GameOverModal status={state.status} message={state.message} onDismiss={() => setDismissed(true)}>
          <button className="btn" onClick={() => setDismissed(true)}>
            Review the board
          </button>
          <button className="btn" onClick={() => setAsking(true)}>
            New players
          </button>
          <button className="btn btn-solid" onClick={rematch} disabled={restarting}>
            Rematch
          </button>
        </GameOverModal>
      )}

      <GameView
        state={state}
        selection={play.selection}
        playable={playable}
        computer={vsComputer}
        thinking={thinking}
        error={error}
        hint={
          over
            ? 'Game over — start another with New game.'
            : thinking
              ? 'The computer is choosing its move.'
              : undefined
        }
        actions={
          <button className="btn btn-solid btn-sm" onClick={() => setAsking(true)}>
            New game
          </button>
        }
      />
    </div>
  );
}
