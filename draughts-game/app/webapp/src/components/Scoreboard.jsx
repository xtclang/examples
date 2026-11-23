import { useQuery } from '@tanstack/react-query';
import { getScores } from '../api.js';
import { Skeleton } from './ui.jsx';
import './Scoreboard.css';

/** Today's scoreboard: the server adds each player's result when a game ends. */
export default function Scoreboard() {
  const scores = useQuery({ queryKey: ['scores'], queryFn: getScores, refetchInterval: 30_000 });
  const rows = scores.data?.table ?? [];

  return (
    <section className="scoreboard" aria-label="Today's scoreboard">
      <h2>Today&apos;s scoreboard</h2>
      {scores.isPending ? (
        <Skeleton width="100%" height="5rem" radius={12} />
      ) : scores.isError ? (
        <p className="empty">Scoreboard unavailable.</p>
      ) : rows.length === 0 ? (
        <p className="empty">No games yet today.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Player</th>
              <th title="Played">P</th>
              <th title="Won">W</th>
              <th title="Drawn">D</th>
              <th title="Lost">L</th>
              <th title="Points">Pts</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.name}>
                <td>{row.name}</td>
                <td>{row.played}</td>
                <td>{row.won}</td>
                <td>{row.drawn}</td>
                <td>{row.lost}</td>
                <td>
                  <b>{row.points}</b>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <p className="scoreboard-note">Win 3 points, draw 1. Resets at midnight (UTC).</p>
    </section>
  );
}
