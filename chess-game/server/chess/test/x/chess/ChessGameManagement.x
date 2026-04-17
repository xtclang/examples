/**
 * Chess Game Management CLI — Functional test tool.
 *
 * Exercises all chess REST API endpoints (single-player, online multiplayer, chat)
 * from the command line using the `@TerminalApp` / `@Command` pattern.
 *
 * Usage:
 *   - Launch while the chess-game web app is running.
 *   - Type a command at the prompt (e.g. "new-game", "move e2 e4").
 *
 * Endpoint mapping:
 *   ChessApi        → /api/...
 *   OnlineChessApi  → /api/online/...
 *   ChatApi         → /api/chat/...
 */
@TerminalApp("Chess Game Management CLI", "Chess>")
module ChessGameManagement.examples.org {
    package webcli import webcli.xtclang.org;

    import webcli.*;

    // =====================================================================
    //  Single-player commands — ChessApi (/api)
    // =====================================================================

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
     * Reset a single-player game with optional time control.
     */
    @Command("reset", "Reset a single-player game")
    String reset(String sessionId) = post($"api/reset/{sessionId}");

    // =====================================================================
    //  Online multiplayer commands — OnlineChessApi (/api/online)
    // =====================================================================

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

    // =====================================================================
    //  Chat commands — ChatApi (/api/chat)
    // =====================================================================

    /**
     * Send a chat message in an online game room.
     */
    @Command("send-message", "Send a chat message (roomCode playerId message)")
    String sendMessage(String roomCode, String playerId, String message) =
        post($|api/chat/send/{roomCode}/{playerId}
            , $|\{"message":"{message}"\}
            );

    /**
     * Retrieve full chat history for a room.
     */
    @Command("chat-history", "Get chat history (roomCode playerId)")
    String chatHistory(String roomCode, String playerId) =
        get($"api/chat/history/{roomCode}/{playerId}");

    /**
     * Retrieve recent chat messages since a given timestamp.
     */
    @Command("recent-messages", "Get recent messages (roomCode playerId sinceMs)")
    String recentMessages(String roomCode, String playerId, String sinceMs) =
        get($"api/chat/recent/{roomCode}/{playerId}/{sinceMs}");

    // =====================================================================
    //  Timed game commands
    // =====================================================================

    /**
     * Start a timed single-player game (e.g. 5 minutes + 3s increment).
     */
    @Command("new-timed-game", "Start a timed game (sessionId timeMs incrementMs)")
    String newTimedGame(String sessionId, String timeMs, String incrementMs) =
        post($"api/reset/{sessionId}", $|\{"timeControlMs":{timeMs},"incrementMs":{incrementMs}\});

    /**
     * Create an online room with time control.
     */
    @Command("create-timed-room", "Create timed online room (timeMs incrementMs)")
    String createTimedRoom(String timeMs, String incrementMs) =
        post("api/online/create", $|\{"timeControlMs":{timeMs},"incrementMs":{incrementMs}\});

    // =====================================================================
    //  Full game flow commands — execute multiple moves in sequence
    // =====================================================================

    /**
     * Scholar's Mate (4-move checkmate): 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7#
     * Plays White's moves and polls state after each AI reply.
     */
    @Command("scholars-mate", "Play Scholar's Mate sequence (sessionId)")
    String scholarsMate(String sessionId) {
        StringBuffer buf = new StringBuffer();

        buf.append("--- Scholar's Mate Flow ---\n");
        buf.append(post($"api/reset/{sessionId}")).append('\n');

        // 1. e4
        buf.append("1. e4: ").append(post($"api/move/{sessionId}/e2/e4")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        // 2. Bc4
        buf.append("2. Bc4: ").append(post($"api/move/{sessionId}/f1/c4")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        // 3. Qh5
        buf.append("3. Qh5: ").append(post($"api/move/{sessionId}/d1/h5")).append('\n');
        buf.append("State: ").append(get($"api/state/{sessionId}")).append('\n');

        // 4. Qxf7#
        buf.append("4. Qxf7#: ").append(post($"api/move/{sessionId}/h5/f7")).append('\n');
        buf.append("Final: ").append(get($"api/state/{sessionId}")).append('\n');

        return buf.toString();
    }

    /**
     * Play a quick opening sequence (Italian Game): 1.e4 e5 2.Nf3 Nc6 3.Bc4
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

    // =====================================================================
    //  Move with promotion
    // =====================================================================

    /**
     * Make a move with pawn promotion (e.g. promote to queen).
     */
    @Command("promote", "Move with promotion (sessionId from target piece)")
    String promote(String sessionId, String from, String target, String piece) =
        post($"api/move/{sessionId}/{from}/{target}?promotion={piece}");

    // =====================================================================
    //  Error-handling / edge-case commands
    // =====================================================================

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
     * Try to join a non-existent online room.
     */
    @Command("bad-room", "Join a non-existent room")
    String badRoom() =
        post("api/online/join/ZZZZZ9");

    /**
     * Get valid moves for starting position pawns and knights.
     */
    @Command("opening-moves", "Show all opening pawn and knight moves (sessionId)")
    String openingMoves(String sessionId) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Opening Valid Moves ---\n");
        buf.append(post($"api/reset/{sessionId}")).append('\n');

        // All pawns
        for (Char file : 'a'..'h') {
            String square = $"{file}2";
            buf.append($"{square}: ").append(get($"api/validmoves/{sessionId}/{square}")).append('\n');
        }
        // Knights
        buf.append("b1: ").append(get($"api/validmoves/{sessionId}/b1")).append('\n');
        buf.append("g1: ").append(get($"api/validmoves/{sessionId}/g1")).append('\n');

        return buf.toString();
    }

    // =====================================================================
    //  Online multiplayer flow commands
    // =====================================================================

    /**
     * Full online game lifecycle: create → join → move → state → reset → leave.
     */
    @Command("online-flow", "Run full online game lifecycle")
    String onlineFlow() {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Full Online Game Flow ---\n");

        // Create room
        buf.append("Create: ").append(post("api/online/create")).append('\n');

        // The room code and player IDs would be extracted from JSON responses
        // in a real test. Here we demonstrate the endpoint calls:
        buf.append("(Extract roomCode & whitePlayerId from Create response above)\n");
        buf.append("(Then call: join-room <roomCode>)\n");
        buf.append("(Then call: online-move <roomCode> <whiteId> e2 e4)\n");
        buf.append("(Then call: online-state <roomCode> <blackId>)\n");
        buf.append("(Then call: online-reset <roomCode> <whiteId>)\n");
        buf.append("(Then call: leave-room <roomCode> <whiteId>)\n");

        return buf.toString();
    }

    /**
     * Send a chat message and then immediately retrieve history.
     */
    @Command("chat-flow", "Send message then read history (roomCode playerId message)")
    String chatFlow(String roomCode, String playerId, String message) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Chat Flow ---\n");

        buf.append("Send: ");
        buf.append(post($|api/chat/send/{roomCode}/{playerId}
                       , $|\{"message":"{message}"\}
                       )).append('\n');

        buf.append("History: ");
        buf.append(get($"api/chat/history/{roomCode}/{playerId}")).append('\n');

        return buf.toString();
    }

    /**
     * Send multiple chat messages rapidly, then fetch history.
     */
    @Command("chat-burst", "Send 3 messages quickly then read history (roomCode playerId)")
    String chatBurst(String roomCode, String playerId) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Chat Burst Test ---\n");

        for (Int i : 1..3) {
            buf.append($"Send {i}: ");
            buf.append(post($|api/chat/send/{roomCode}/{playerId}
                           , $|\{"message":"Test message {i}"\}
                           )).append('\n');
        }

        buf.append("History: ");
        buf.append(get($"api/chat/history/{roomCode}/{playerId}")).append('\n');

        return buf.toString();
    }

    // =====================================================================
    //  Game-state inspection commands
    // =====================================================================

    /**
     * Play multiple moves and dump the full move history.
     */
    @Command("move-history", "Play e4-d5-exd5 and show move history (sessionId)")
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
     * Verify that reset truly clears the board back to starting position.
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
