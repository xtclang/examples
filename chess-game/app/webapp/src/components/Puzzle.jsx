import { useEffect, useRef, useState } from 'react';
import Board from './Board.jsx';
import { useGame } from '../lib/analyse.js';
import { getReplayValidMoves } from '../api.js';
import './Puzzle.css';

/** How long the opponent's reply waits before it plays, so it reads as a reply and not a jump. */
const REPLY_DELAY_MS = 500;
/** How long the wrong-move shake stays on screen before the attempt is cleared. */
const WRONG_FLASH_MS = 450;

/** One daily puzzle, played out move by move: the user attempts the solving side's moves, the
 *  other side's replies play themselves, and a wrong attempt is rejected on the spot. The
 *  solution's frames and legal moves come from the server (see PgnReplayApi.x) -- the puzzle's
 *  FEN can start anywhere, and resolving its PGN solution needs the position's legal moves. */
export default function Puzzle({ puzzle, onExit }) {
  const solution = useGame({ fen: puzzle.fen, pgn: puzzle.pgn });
  const flipped = puzzle.fen.split(' ')[1] === 'b';

  const [ply, setPly] = useState(0);
  const [selected, setSelected] = useState(null);
  const [targets, setTargets] = useState([]);
  const [wrong, setWrong] = useState(false);
  const selectedRef = useRef(null);
  useEffect(() => {
    setPly(0);
    setSelected(null);
    setTargets([]);
    setWrong(false);
  }, [puzzle.fen, puzzle.pgn]);

  const moves = solution.moves;
  const loading = !solution.error && solution.positions.length === 0;
  const solved = moves.length > 0 && ply >= moves.length;
  const solverTurn = ply % 2 === 0;

  // The side being replied to plays itself, the same way the computer's move lands in
  // single-player: a short pause, then the next ply.
  useEffect(() => {
    if (loading || solved || solverTurn) return;
    const t = setTimeout(() => setPly((p) => p + 1), REPLY_DELAY_MS);
    return () => clearTimeout(t);
  }, [ply, loading, solved, solverTurn]);

  const frame = solution.positions[Math.min(ply, solution.positions.length - 1)] ?? null;

  useEffect(() => {
    setSelected(null);
    setTargets([]);
  }, [ply]);

  const wrongTimer = useRef(0);
  const attempt = (from, to) => {
    const expected = moves[ply];
    setSelected(null);
    setTargets([]);
    if (expected && expected.from === from && expected.to === to) {
      setPly((p) => p + 1);
      setWrong(false);
      return;
    }
    setWrong(true);
    clearTimeout(wrongTimer.current);
    wrongTimer.current = setTimeout(() => setWrong(false), WRONG_FLASH_MS);
  };

  const touch = async (square) => {
    if (!solverTurn || solved || !frame) return;

    if (selected === square) {
      setSelected(null);
      setTargets([]);
      return;
    }
    if (selected && targets.includes(square)) {
      attempt(selected, square);
      return;
    }

    setSelected(square);
    setTargets([]);
    selectedRef.current = square;
    try {
      const reply = await getReplayValidMoves(frame.fen, square);
      if (selectedRef.current === square) {
        setTargets(reply.success ? reply.validMoves ?? [] : []);
      }
    } catch {
      if (selectedRef.current === square) {
        setSelected(null);
      }
    }
  };

  if (solution.error || (!loading && moves.length === 0)) {
    return (
      <div className="puzzle">
        <p className="error">Couldn't read this puzzle's solution.</p>
        <button className="btn" onClick={onExit}>Back</button>
      </div>
    );
  }

  if (loading || !frame) {
    return <div className="puzzle" aria-busy="true" />;
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
          board={frame.board}
          highlight={frame.squares}
          selected={selected}
          targets={targets}
          onSelect={solverTurn && !solved ? touch : null}
          flipped={flipped}
          moveKey={ply}
        />
      </div>
      {solved && (
        <button className="btn btn-solid" onClick={() => { setPly(0); setSelected(null); setTargets([]); }}>
          Solve again
        </button>
      )}
    </div>
  );
}
