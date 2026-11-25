import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ConfirmModal } from './Modals.jsx';
import { Skeleton } from './ui.jsx';
import './Scoreboard.css';

/**
 * The scoreboard of one game: a single-player session, or a room across all its rematches.
 *
 * Each game keeps its own tally, which starts at nothing, and once the game has ended it can be
 * reset to start the match afresh. The button waits for the game to end, because resetting in
 * the middle would leave a game in progress with a scoreboard that forgot the ones before it.
 *
 * @param scope     what is being scored, for display: "This game" or "Room K7M2QX"
 * @param id        identifies the scoreboard for caching; it changes when the game changes
 * @param load      fetches the scoreboard
 * @param reset     clears it
 * @param canReset  whether the game has ended (or has not begun)
 * @param version   changes when a game ends or a move is made, so the table refreshes at once
 * @param poll      how often to ask again, in ms, e.g. to see the other player's reset
 */
export default function Scoreboard({ scope, id, load, reset, canReset, version, poll = false }) {
  const client = useQueryClient();
  const key = ['scores', id];
  const scores = useQuery({ queryKey: [...key, version], queryFn: load, refetchInterval: poll });
  const rows = scores.data?.table ?? [];
  const [confirming, setConfirming] = useState(false);

  const clear = useMutation({
    mutationFn: reset,
    onSuccess: (next) => {
      client.invalidateQueries({ queryKey: key });
      if (next.success) setConfirming(false);
    },
  });
  const refused = clear.data && !clear.data.success ? clear.data.message : '';

  return (
    <section className="scoreboard" aria-label="Scoreboard">
      <header className="scoreboard-head">
        <div>
          <h2>Scoreboard</h2>
          <p className="scoreboard-scope">{scope}</p>
        </div>
        <button
          className="btn btn-sm"
          onClick={() => setConfirming(true)}
          disabled={!canReset || rows.length === 0 || clear.isPending}
          title={canReset ? 'Clear the scoreboard' : 'Available once the game has ended'}
        >
          Reset
        </button>
      </header>

      {scores.isPending ? (
        <Skeleton width="100%" height="5rem" radius={12} />
      ) : scores.isError ? (
        <p className="empty">Scoreboard unavailable.</p>
      ) : rows.length === 0 ? (
        <p className="empty">No games finished yet.</p>
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

      {refused && <p className="error">{refused}</p>}
      <p className="scoreboard-note">
        Win 3 points, draw 1. {canReset ? 'You can reset it now the game has ended.' : 'Reset opens when the game ends.'}
      </p>

      {confirming && (
        <ConfirmModal
          title="Reset the scoreboard?"
          message="This clears every result for this game, for everyone in it. It cannot be undone."
          confirm="Reset"
          cancel="Keep"
          busy={clear.isPending}
          onCancel={() => setConfirming(false)}
          onConfirm={() => clear.mutate()}
        />
      )}
    </section>
  );
}

/** What the panel shows in a room that has not been entered yet. */
export function NoScoreboard() {
  return (
    <section className="scoreboard" aria-label="Scoreboard">
      <header className="scoreboard-head">
        <div>
          <h2>Scoreboard</h2>
          <p className="scoreboard-scope">Per game</p>
        </div>
      </header>
      <p className="empty">Create or join a room and its games are scored here.</p>
    </section>
  );
}
