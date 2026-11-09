import { useEffect, useMemo, useRef, useState } from 'react';
import { Chess } from 'chess.js';
import Board from './Board.jsx';
import { puzzleSolution } from '../lib/analyse.js';
import './Puzzle.css';

/** How long the opponent's reply waits before it plays, so it reads as a reply and not a jump. */
const REPLY_DELAY_MS = 500;
/** How long the wrong-move shake stays on screen before the attempt is cleared. */
const WRONG_FLASH_MS = 450;

/** Replays the solution up to `ply` from `fen`, for the board shown and the targets offered. */
function frameAt(fen, solution, ply) {
  const game = new Chess(fen);
  for (let i = 0; i < ply; i++) {
    game.move({ from: solution[i].from, to: solution[i].to, promotion: solution[i].promotion ?? undefined });
  }
  return { board: game.board(), fen: game.fen(), lastMove: ply > 0 ? solution[ply - 1] : null };
}

/** One daily puzzle, played out move by move: the user attempts the solving side's moves, the
 *  other side's replies play themselves, and a wrong attempt is rejected on the spot. */
export default function Puzzle({ puzzle, onExit }) {
  const solution = useMemo(() => puzzleSolution(puzzle.fen, puzzle.pgn), [puzzle.fen, puzzle.pgn]);
  const flipped = puzzle.fen.split(' ')[1] === 'b';

  const [ply, setPly] = useState(0);
  const [selected, setSelected] = useState(null);
  const [wrong, setWrong] = useState(false);
  useEffect(() => {
    setPly(0);
    setSelected(null);
    setWrong(false);
  }, [puzzle.fen, puzzle.pgn]);

  const solved = solution.length > 0 && ply >= solution.length;
  const solverTurn = ply % 2 === 0;

  // The side being replied to plays itself, the same way the computer's move lands in
  // single-player: a short pause, then the next ply.
  useEffect(() => {
    if (solved || solverTurn) return;
    const t = setTimeout(() => setPly((p) => p + 1), REPLY_DELAY_MS);
    return () => clearTimeout(t);
  }, [ply, solved, solverTurn]);

  const frame = useMemo(() => frameAt(puzzle.fen, solution, ply), [puzzle.fen, solution, ply]);

  const targets = useMemo(() => {
    if (!selected) return [];
    try {
      return new Chess(frame.fen).moves({ square: selected, verbose: true }).map((m) => m.to);
    } catch {
      return [];
    }
  }, [selected, frame.fen]);

  const wrongTimer = useRef(0);
  const attempt = (from, to) => {
    const expected = solution[ply];
    if (expected && expected.from === from && expected.to === to) {
      setPly((p) => p + 1);
      setSelected(null);
      setWrong(false);
      return;
    }
    setSelected(null);
    setWrong(true);
    clearTimeout(wrongTimer.current);
    wrongTimer.current = setTimeout(() => setWrong(false), WRONG_FLASH_MS);
  };

  const touch = (square) => {
    if (!solverTurn || solved) return;
    if (selected === square) {
      setSelected(null);
      return;
    }
    if (selected && targets.includes(square)) {
      attempt(selected, square);
      return;
    }
    setSelected(square);
  };

  if (solution.length === 0) {
    return (
      <div className="puzzle">
        <p className="error">Couldn't read this puzzle's solution.</p>
        <button className="btn" onClick={onExit}>Back</button>
      </div>
    );
  }

  const status = solved
    ? 'Solved!'
    : wrong
      ? 'Not quite — try again.'
      : solverTurn
        ? `Find the best move for ${puzzle.fen.includes(' w ') ? 'White' : 'Black'}.`
        : "Opponent's move…";

  return (
    <div className="puzzle">
      <h2 className="board-title">{puzzle.title}</h2>
      <p className="play-status" aria-live="polite">
        <span className={`status-dot ${solved ? 'ready' : wrong ? 'wrong' : solverTurn ? 'ready' : 'busy'}`} aria-hidden="true" />
        {status}
      </p>
      <div className={`board-wrap${wrong ? ' puzzle-wrong' : ''}`}>
        <Board
          board={frame.board.map((rank) => rank.map((p) => (p ? { type: p.type, color: p.color } : null)))}
          highlight={frame.lastMove ? [frame.lastMove.from, frame.lastMove.to] : []}
          selected={selected}
          targets={targets}
          onSelect={solverTurn && !solved ? touch : null}
          flipped={flipped}
          moveKey={ply}
        />
      </div>
      {solved && (
        <button className="btn btn-solid" onClick={() => { setPly(0); setSelected(null); }}>
          Solve again
        </button>
      )}
    </div>
  );
}
