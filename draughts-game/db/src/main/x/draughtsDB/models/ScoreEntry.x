/**
 * Score Entry - one player's results in one match.
 *
 * The scoreboard is keyed by "{scope}|{nickname}", where the scope is one match (a room, or a
 * single-player session), so each match keeps its own tally and can be reset. A win is worth 3
 * points and a draw 1.
 */
const ScoreEntry(String name,
                 Int played = 0,
                 Int won = 0,
                 Int drawn = 0,
                 Int lost = 0) {
    /**
     * Points on the board: 3 for a win, 1 for a draw.
     */
    @RO Int points.get() = won * 3 + drawn;

    /**
     * This entry with one more result added.
     */
    ScoreEntry record(Boolean win, Boolean draw) {
        return new ScoreEntry(name, played + 1,
                              won   + (win          ? 1 : 0),
                              drawn + (draw         ? 1 : 0),
                              lost  + (!win && !draw ? 1 : 0));
    }
}
