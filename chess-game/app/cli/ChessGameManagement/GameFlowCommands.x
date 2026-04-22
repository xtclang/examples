import webcli.*;

/**
 * Scripted multi-move game sequences.
 *
 * Executes a fixed series of moves against the AI, printing the board state
 * after each reply so the output can be inspected manually.
 */
mixin GameFlowCommands {

    /**
     * Scholar's Mate (4-move checkmate): 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7#
     *
     * Plays White's moves and polls state after each AI reply.
     */
    @Command("scholars-mate", "Play Scholar's Mate sequence (sessionId)")
    String scholarsMate(String sessionId) {
        StringBuffer buf = new StringBuffer();

        buf.append("--- Scholar's Mate Flow ---\n");
        buf.append(post($"api/reset/{sessionId}")).append('\n');

        buf.append("1. e4: ").append(post($"api/move/{sessionId}/e2/e4")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        buf.append("2. Bc4: ").append(post($"api/move/{sessionId}/f1/c4")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        buf.append("3. Qh5: ").append(post($"api/move/{sessionId}/d1/h5")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        buf.append("4. Qxf7#: ").append(post($"api/move/{sessionId}/h5/f7")).append('\n');
        buf.append("Final: ").append(get($"api/state/{sessionId}")).append('\n');

        return buf.toString();
    }

    /**
     * Italian Game opening: 1.e4 e5 2.Nf3 Nc6 3.Bc4
     */
    @Command("italian-opening", "Play Italian Game opening (sessionId)")
    String italianOpening(String sessionId) {
        StringBuffer buf = new StringBuffer();

        buf.append("--- Italian Game Opening ---\n");
        buf.append(post($"api/reset/{sessionId}")).append('\n');

        buf.append("1. e4: ").append(post($"api/move/{sessionId}/e2/e4")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        buf.append("2. Nf3: ").append(post($"api/move/{sessionId}/g1/f3")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        buf.append("3. Bc4: ").append(post($"api/move/{sessionId}/f1/c4")).append('\n');
        buf.append("Final: ").append(get($"api/state/{sessionId}")).append('\n');

        return buf.toString();
    }
}
