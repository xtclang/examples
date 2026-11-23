import db.models.GameRecord;
import db.models.ScoreEntry;

/**
 * Scoreboard - puts a finished game's results on the day's board.
 *
 * Shared by the single-player service and the rooms, so a game counts the same wherever it was
 * played. A win is worth 3 points and a draw 1.
 */
service Scoreboard {
    /**
     * Add a finished game to the board for `date`: one result for each player.
     */
    static void record(DraughtsSchema schema, String date, GameRecord game) {
        Color? winner = DraughtsGame.winnerOf(game.status);
        add(schema, date, game.blackName, winner == Black, winner == Null);
        add(schema, date, game.whiteName, winner == White, winner == Null);
    }

    private static void add(DraughtsSchema schema, String date, String name,
                            Boolean win, Boolean draw) {
        String     key     = DraughtsGame.scoreKey(date, name);
        ScoreEntry current = schema.scores.getOrDefault(key, new ScoreEntry(name));
        schema.scores.put(key, current.record(win, draw));
    }
}
