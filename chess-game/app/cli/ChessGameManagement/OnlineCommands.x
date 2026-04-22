import webcli.*;

/**
 * Online multiplayer chess commands.
 *
 * Covers the /api/online/... endpoints:
 *   - room lifecycle : create-room, join-room, online-reset, leave-room
 *   - gameplay       : online-move, online-state, online-valid-moves
 *   - error probes   : bad-room
 *   - scripted flow  : online-flow
 */
mixin OnlineCommands {

    /**
     * Create a new online room (caller becomes White).
     */
    @Command("create-room", "Create a new online game room")
    String createRoom() = post("api/online/create");

    /**
     * Join an existing room (caller becomes Black).
     */
    @Command("join-room", "Join an online game room (roomCode)")
    String joinRoom(String roomCode) = post($"api/online/join/{roomCode}");

    /**
     * Get the state of an online game.
     */
    @Command("online-state", "Get online game state (roomCode playerId)")
    String onlineState(String roomCode, String playerId) =
        get($"api/online/state/{roomCode}/{playerId}");

    /**
     * Make a move in an online game.
     */
    @Command("online-move", "Make a move online (roomCode playerId from target)")
    String onlineMove(String roomCode, String playerId, String from, String target) =
        post($"api/online/move/{roomCode}/{playerId}/{from}/{target}");

    /**
     * Reset an online game (preserves players).
     */
    @Command("online-reset", "Reset an online game (roomCode playerId)")
    String onlineReset(String roomCode, String playerId) =
        post($"api/online/reset/{roomCode}/{playerId}");

    /**
     * Leave an online game.
     */
    @Command("leave-room", "Leave an online game (roomCode playerId)")
    String leaveRoom(String roomCode, String playerId) =
        post($"api/online/leave/{roomCode}/{playerId}");

    /**
     * Get valid moves for a piece in an online game.
     */
    @Command("online-valid-moves", "Get valid moves online (roomCode playerId square)")
    String onlineValidMoves(String roomCode, String playerId, String square) =
        get($"api/online/validmoves/{roomCode}/{playerId}/{square}");

    /**
     * Try to join a non-existent online room.
     */
    @Command("bad-room", "Join a non-existent room")
    String badRoom() =
        post("api/online/join/ZZZZZ9");

    /**
     * Full online game lifecycle: create → join → move → state → reset → leave.
     *
     * Demonstrates the endpoint sequence; room code and player IDs must be
     * extracted from the JSON responses and passed to subsequent commands.
     */
    @Command("online-flow", "Run full online game lifecycle")
    String onlineFlow() {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Full Online Game Flow ---\n");

        buf.append("Create: ").append(post("api/online/create")).append('\n');

        buf.append("(Extract roomCode & whitePlayerId from Create response above)\n");
        buf.append("(Then call: join-room <roomCode>)\n");
        buf.append("(Then call: online-move <roomCode> <whiteId> e2 e4)\n");
        buf.append("(Then call: online-state <roomCode> <blackId>)\n");
        buf.append("(Then call: online-reset <roomCode> <whiteId>)\n");
        buf.append("(Then call: leave-room <roomCode> <whiteId>)\n");

        return buf.toString();
    }
}
