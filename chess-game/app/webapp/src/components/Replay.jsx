import Board from './Board.jsx';

/** Steps through the frames of a game, or shows a single position. */
export default function Replay({ positions, moves, title, flipped, ply, setPly, error }) {
  if (error) return <p className="error">Could not read game: {error}</p>;
  if (!positions.length) return null;

  const idx = Math.min(ply, positions.length - 1);
  const pos = positions[idx];

  return (
    <div className="replay">
      {title && <h2 className="board-title">{title}</h2>}
      <Board board={pos.board} highlight={pos.squares} flipped={flipped} />
      {moves.length > 0 && (
        <>
          <div className="controls">
            <button onClick={() => setPly(0)} disabled={idx === 0} aria-label="First move">⏮</button>
            <button onClick={() => setPly(idx - 1)} disabled={idx === 0} aria-label="Previous move">◀</button>
            <span className="counter">{idx} / {moves.length}</span>
            <button onClick={() => setPly(idx + 1)} disabled={idx === moves.length} aria-label="Next move">▶</button>
            <button onClick={() => setPly(moves.length)} disabled={idx === moves.length} aria-label="Last move">⏭</button>
          </div>
          <ol className="moves">
            {moves.map((san, i) => (
              <li key={i}>
                <button className={i + 1 === idx ? 'active' : ''} onClick={() => setPly(i + 1)}>
                  {i % 2 === 0 && <span className="no">{i / 2 + 1}.</span>}
                  {san}
                </button>
              </li>
            ))}
          </ol>
        </>
      )}
    </div>
  );
}
