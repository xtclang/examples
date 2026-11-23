import db.models.ScoreEntry;

/**
 * ScoresApi Service
 *
 * The public scoreboard for today: one row per nickname with games played, won, drawn and lost,
 * and points (3 for a win, 1 for a draw). The server adds to it when a game finishes (see
 * DraughtsApi); the board starts afresh at midnight (UTC) because every row is keyed by date.
 *
 * - GET /api/scores
 */
@WebService("/api")
service ScoresApi {
    // Database access; see the Database service in draughts.x
    @Lazy DraughtsSchema schema.calc() = Database.connect();
    @Inject Clock clock;

    /**
     * GET /api/scores
     *
     * Today's table, best first: by points, then wins, then name.
     */
    @Get("scores")
    @Produces(Json)
    @HttpsRequired
    ScoreTable scores() {
        using (schema.createTransaction()) {
            String prefix = $"{clock.now.date}|";
            ScoreRow[] rows = new Array<ScoreRow>();
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
    }

    /**
     * One row of the scoreboard.
     */
    static const ScoreRow(String name, Int played, Int won, Int drawn, Int lost, Int points);

    /**
     * The scoreboard as sent to the client.
     */
    static const ScoreTable(ScoreRow[] table);
}
