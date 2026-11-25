import db.models.GameRecord;
import db.models.ScoreEntry;

/**
 * Scoreboard - the tally of one match.
 *
 * A match is a room (every game its two players play there, rematch after rematch) or a
 * single-player session. Each has its own scoreboard, so one game's results never mix with
 * another's. A win is worth 3 points and a draw 1.
 *
 * A scoreboard can be reset once the game in front of the players has ended (or before it has
 * begun), which clears the tally and lets the match start afresh. Rows are kept per scope:
 * "{scope}|{nickname}".
 */
service Scoreboard {
    /**
     * One row of a scoreboard.
     */
    static const ScoreRow(String name, Int played, Int won, Int drawn, Int lost, Int points);

    /**
     * A scoreboard as sent to the client.
     *
     * @param table    the rows, best first: by points, then wins, then name
     * @param success  False if a reset was refused
     * @param message  why a reset was refused
     */
    static const ScoreTable(ScoreRow[] table, Boolean success = True, String message = "");

    /**
     * The scope of a single-player session's scoreboard.
     */
    static String sessionScope(String sessionId) = $"game:{sessionId}";

    /**
     * The scope of a room's scoreboard.
     */
    static String roomScope(String roomCode) = $"room:{roomCode}";

    /**
     * True if the scoreboard may be reset now: the game has ended, or has not yet started.
     */
    static Boolean canReset(GameRecord game) = game.status != Ongoing || game.history.empty;

    /**
     * Add a finished game to a scoreboard: one result for each player.
     */
    static void record(DraughtsSchema schema, String scope, GameRecord game) {
        Color? winner = DraughtsGame.winnerOf(game.status);
        add(schema, scope, game.blackName, winner == Black, winner == Null);
        add(schema, scope, game.whiteName, winner == White, winner == Null);
    }

    private static void add(DraughtsSchema schema, String scope, String name,
                            Boolean win, Boolean draw) {
        String     key     = DraughtsGame.scoreKey(scope, name);
        ScoreEntry current = schema.scores.getOrDefault(key, new ScoreEntry(name));
        schema.scores.put(key, current.record(win, draw));
    }

    /**
     * A scoreboard's rows, best first.
     */
    static ScoreTable table(DraughtsSchema schema, String scope) {
        String     prefix = $"{scope}|";
        ScoreRow[] rows   = new Array<ScoreRow>();
        for (String key : schema.scores.keys) {
            if (key.startsWith(prefix), ScoreEntry entry := schema.scores.get(key)) {
                rows.add(new ScoreRow(entry.name, entry.played, entry.won, entry.drawn,
                                      entry.lost, entry.points));
            }
        }
        return new ScoreTable(rows.sorted((a, b) -> {
            Ordered byPoints = b.points <=> a.points;
            if (byPoints != Equal) {
                return byPoints;
            }
            Ordered byWins = b.won <=> a.won;
            return byWins != Equal ? byWins : a.name <=> b.name;
        }));
    }

    /**
     * Clear a scoreboard.
     */
    static void reset(DraughtsSchema schema, String scope) {
        String   prefix = $"{scope}|";
        String[] doomed = new Array<String>();
        for (String key : schema.scores.keys) {
            if (key.startsWith(prefix)) {
                doomed.add(key);
            }
        }
        for (String key : doomed) {
            schema.scores.remove(key);
        }
    }
}
