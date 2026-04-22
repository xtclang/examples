import webcli.*;

/**
 * Single-player chess commands.
 *
 * Covers the core /api/... endpoints:
 *   - game lifecycle  : new-game, reset, game-state
 *   - move execution  : move, valid-moves, promote
 *   - state inspection: opening-moves, move-history, reset-verify
 *   - error probes    : bad-move, bad-session
 */
mixin SinglePlayerCommands {

    /**
     * Start (or reset) a single-player game for the given session.
     */
    @Command("new-game", "Reset/create a single-player game")
    String newGame(String sessionId) = post($"api/reset/{sessionId}");

    /**
     * Get the current game state for a session.
     */
    @Command("game-state", "Get current game state")
    String gameState(String sessionId) = get($"api/state/{sessionId}");

    /**
     * Make a move in a single-player game.
     *
     * @param sessionId  browser session id
     * @param from       source square  (e.g. "e2")
     * @param target     destination    (e.g. "e4")
     */
    @Command("move", "Make a move (sessionId from target)")
    String move(String sessionId, String from, String target) =
        post($"api/move/{sessionId}/{from}/{target}");

    /**
     * List the valid destination squares for a piece.
     */
    @Command("valid-moves", "Get valid moves for a square (sessionId square)")
    String validMoves(String sessionId, String square) =
        get($"api/validmoves/{sessionId}/{square}");

    /**
     * Reset a single-player game.
     */
    @Command("reset", "Reset a single-player game")
    String reset(String sessionId) = post($"api/reset/{sessionId}");

    /**
     * Make a move with pawn promotion (e.g. promote to queen).
     */
    @Command("promote", "Move with promotion (sessionId from target piece)")
    String promote(String sessionId, String from, String target, String piece) =
        post($"api/move/{sessionId}/{from}/{target}?promotion={piece}");

    /**
     * Attempt an invalid move to verify error handling.
     */
    @Command("bad-move", "Try an illegal move (sessionId from target)")
    String badMove(String sessionId, String from, String target) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Testing invalid move ---\n");
        buf.append("Move ").append(from).append("->").append(target).append(": ");
        buf.append(post($"api/move/{sessionId}/{from}/{target}")).append('\n');
        return buf.toString();
    }

    /**
     * Attempt to move for a non-existent session.
     */
    @Command("bad-session", "Test move with unknown session")
    String badSession() =
        post("api/move/nonexistent-session-xyz/e2/e4");

    /**
     * Get valid moves for all starting-position pawns and knights.
     */
    @Command("opening-moves", "Show all opening pawn and knight moves (sessionId)")
    String openingMoves(String sessionId) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Opening Valid Moves ---\n");
        buf.append(post($"api/reset/{sessionId}")).append('\n');

        for (Char file : 'a'..'h') {
            String square = $"{file}2";
            buf.append($"{square}: ").append(get($"api/validmoves/{sessionId}/{square}")).append('\n');
        }
        buf.append("b1: ").append(get($"api/validmoves/{sessionId}/b1")).append('\n');
        buf.append("g1: ").append(get($"api/validmoves/{sessionId}/g1")).append('\n');

        return buf.toString();
    }

    /**
     * Play e4 then d4 and print the resulting move history.
     */
    @Command("move-history", "Play e4-d4 and show move history (sessionId)")
    String moveHistory(String sessionId) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Move History Test ---\n");
        buf.append(post($"api/reset/{sessionId}")).append('\n');

        buf.append("1. e4: ").append(post($"api/move/{sessionId}/e2/e4")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        buf.append("2. d4: ").append(post($"api/move/{sessionId}/d2/d4")).append('\n');
        buf.append("Final state (with move history): ").append(get($"api/state/{sessionId}")).append('\n');

        return buf.toString();
    }

    /**
     * Verify that reset truly clears the board back to the starting position.
     */
    @Command("reset-verify", "Make a move, reset, then verify initial state (sessionId)")
    String resetVerify(String sessionId) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Reset Verification ---\n");

        buf.append("Initial: ").append(post($"api/reset/{sessionId}")).append('\n');
        buf.append("Move e4: ").append(post($"api/move/{sessionId}/e2/e4")).append('\n');
        buf.append("After move: ").append(get($"api/state/{sessionId}")).append('\n');
        buf.append("Reset: ").append(post($"api/reset/{sessionId}")).append('\n');
        buf.append("After reset: ").append(get($"api/state/{sessionId}")).append('\n');

        return buf.toString();
    }
}
