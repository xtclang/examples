/**
 * Score Entry - one player's results for one day.
 *
 * The scoreboard is keyed by "{date}|{nickname}", so it starts afresh every day. A win is worth
 * 3 points and a draw 1.
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
