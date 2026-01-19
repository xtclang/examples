import OnlineChessLogic.RoomCreated;
import OnlineChessLogic.OnlineApiState;
import ChessGame.MoveOutcome;
import ChessGame.AutoResponse;
import db.GameStatus;
/**
 * ChessApi Service
 *
 * RESTful API service for chess game operations. Provides endpoints for:
 * - Getting current game state
 * - Making player moves
 * - Resetting the game
 *
 * The API implements simplified chess rules without castling, en-passant,
 * or explicit check/checkmate detection. The opponent (Black) is automated
 * with AI-driven move selection after a configurable delay.
 *
 * All operations are transactional to ensure data consistency.
 * Each browser session gets its own independent game via session IDs.
 */
@WebService("/api")
service ChessApi {
    // Injected dependencies for database access and time tracking
    @Inject ChessSchema schema;  // Database schema for game persistence
    @Inject Clock         clock; // System clock for timing opponent moves

    // Per-session pending state tracking
    @Atomic private Map<String, Boolean> pendingActiveMap = new HashMap();
    @Atomic private Map<String, Time> pendingStartMap = new HashMap();
    @Atomic private Boolean autoApplied;    // True if an auto-move was just applied

    // Duration to wait before opponent makes a move (3 seconds)
    @RO Duration moveDelay.get() = Duration.ofSeconds(3);

    /**
     * GET /api/state/{sessionId}
     *
     * Retrieves the current state of the chess game for a specific session.
     *
     * @param sessionId The unique session identifier for this browser
     * @return ApiState object containing complete game state as JSON
     */
    @Get("state/{sessionId}")
    @Produces(Json)
    ApiState state(String sessionId) {
        using (schema.createTransaction()) {
            // Ensure a game exists for this session
            GameRecord record = ensureGame(sessionId);
            // Check if opponent should make an automatic move
            GameRecord updated = maybeResolveAuto(record, sessionId);
            // Save the game if an auto-move was applied
            if (autoApplied) {
                saveGame(sessionId, updated);
            }
            // Convert to API format and return
            return toApiState(updated, Null, sessionId);
        }
    }

    /**
     * POST /api/move/{sessionId}/{from}/{target}
     *
     * Executes a player's chess move from one square to another.
     *
     * @param sessionId The unique session identifier for this browser
     * @param from   Source square in algebraic notation (e.g., "e2")
     * @param target Destination square in algebraic notation (e.g., "e4")
     * @return ApiState with updated game state or error message if move was illegal
     */
    @Post("move/{sessionId}/{from}/{target}")
    @Produces(Json)
    ApiState move(String sessionId, String from, String target) {
        using (schema.createTransaction()) {
            // Ensure game exists for this session
            GameRecord record = ensureGame(sessionId);
            try {
                // Validate and apply the human player's move
                MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                if (result.ok) {
                    // Move was legal, check if opponent should respond
                    GameRecord current = maybeResolveAuto(result.record, sessionId);
                    // Persist the updated game state
                    saveGame(sessionId, current);
                    return toApiState(current, Null, sessionId);
                }
                // Move was illegal, return error message
                return toApiState(result.record, result.message, sessionId);
            } catch (Exception e) {
                // Handle unexpected errors gracefully
                return toApiState(record, $"Server error: {e.toString()}", sessionId);
            }
        }
    }

    /**
     * POST /api/reset/{sessionId}
     *
     * Resets the game for a specific session to initial state.
     *
     * @param sessionId The unique session identifier for this browser
     * @return ApiState with fresh game state and confirmation message
     */
    @Post("reset/{sessionId}")
    @Produces(Json)
    ApiState reset(String sessionId) {
        using (schema.createTransaction()) {
            // Remove existing game from database
            schema.singlePlayerGames.remove(sessionId);
            // Create a fresh game with initial board setup
            GameRecord resetGame = ChessLogic.resetGame();
            // Save the new game
            schema.singlePlayerGames.put(sessionId, resetGame);
            // Clear pending move flags for this session
            pendingActiveMap.put(sessionId, False);
            autoApplied = False;
            return toApiState(resetGame, "New game started", sessionId);
        }
    }


    /**
     * API Response Data Structure
     *
     * Immutable data object representing the complete game state for API responses.
     * This is serialized to JSON and sent to the web client.
     *
     * @param board            Array of 8 strings, each representing one rank (row) of the board
     * @param turn             Current player's turn ("White" or "Black")
     * @param status           Game status ("Ongoing", "Checkmate", or "Stalemate")
     * @param message          Human-readable status message for display
     * @param lastMove         Last move made in algebraic notation (e.g., "e2e4"), or null
     * @param playerScore      Number of opponent pieces captured by White
     * @param opponentScore    Number of player pieces captured by Black
     * @param opponentPending  True if the opponent is currently "thinking"
     */
    static const ApiState(String[] board,
                   String turn,
                   String status,
                   String message,
                   String? lastMove,
                   Int playerScore,
                   Int opponentScore,
                   Boolean opponentPending);


    // ----- Helper Methods ------------------------------------------------------

    /**
     * Ensures a game record exists in the database for a given session.
     * If no game exists, creates a new one with default starting position.
     *
     * @param sessionId The unique session identifier
     * @return The existing or newly created GameRecord
     */
    GameRecord ensureGame(String sessionId) {
        // Try to get existing game, or use default if not found
        GameRecord record = schema.singlePlayerGames.getOrDefault(sessionId, ChessLogic.defaultGame());
        // If game wasn't in database, save it now
        if (!schema.singlePlayerGames.contains(sessionId)) {
            schema.singlePlayerGames.put(sessionId, record);
        }
        return record;
    }

    /**
     * Persists the game record to the database for a given session.
     *
     * @param sessionId The unique session identifier
     * @param record The GameRecord to save
     */
    void saveGame(String sessionId, GameRecord record) {
        schema.singlePlayerGames.put(sessionId, record);
    }

    /**
     * Converts internal GameRecord to API response format.
     *
     * @param record  The game record from database
     * @param message Optional custom message (e.g., error message)
     * @param sessionId The session identifier for pending state lookup
     * @return ApiState object ready for JSON serialization
     */
    ApiState toApiState(GameRecord record, String? message = Null, String sessionId = "") {
        // Check if opponent is currently thinking
        Boolean pendingActive = pendingActiveMap.getOrDefault(sessionId, False);
        Boolean pending = pendingActive && isOpponentPending(record);
        // Generate appropriate status message
        String  detail  = message ?: describeState(record, pending);
        // Construct API state with all game information
        return new ApiState(
                ChessLogic.boardRows(record.board),  // Board as array of 8 strings
                record.turn.toString(),               // "White" or "Black"
                record.status.toString(),             // Game status
                detail,                               // Descriptive message
                record.lastMove,                      // Last move notation (e.g., "e2e4")
                record.playerScore,                   // White's capture count
                record.opponentScore,                 // Black's capture count
                pending);                             // Is opponent thinking?
    }

    /**
     * Determines if the opponent (Black) should be making a move.
     *
     * @param record Current game state
     * @return True if game is ongoing and it's Black's turn
     */
    Boolean isOpponentPending(GameRecord record) {
        return record.status == GameStatus.Ongoing && record.turn == Color.Black;
    }

    /**
     * Generates a human-readable description of the current game state.
     *
     * @param record  Current game state
     * @param pending Whether opponent is currently thinking
     * @return Descriptive message for display to user
     */
    String describeState(GameRecord record, Boolean pending) {
        // Handle game-over states
        switch (record.status) {
        case GameStatus.Checkmate:
            // Determine winner based on whose turn it is (loser has no pieces)
            return record.turn == Color.White
                    ? "Opponent captured all your pieces. Game over."
                    : "You captured every opponent piece. Victory!";

        case GameStatus.Stalemate:
            // Only kings remain - draw condition
            return "Only kings remain. Stalemate.";

        default:
            break;
        }

        // Game is ongoing - describe current move state
        String? move = record.lastMove;
        if (pending) {
            // Opponent is thinking about their next move
            return move == Null
                    ? "Opponent thinking..."
                    : $"You moved {move}. Opponent thinking...";
        }

        if (record.turn == Color.White) {
            // It's the player's turn
            return move == Null
                    ? "Your move."
                    : $"Opponent moved {move}. Your move.";
        }

        // Default message when waiting for player
        return "Your move.";
    }

    /**
     * Checks if enough time has passed for the opponent to make an automated move.
     *
     * This method implements the AI opponent's "thinking" delay:
     * 1. If it's not opponent's turn, do nothing
     * 2. If opponent just started thinking, record the start time
     * 3. If enough time has passed (moveDelay), execute the opponent's move
     *
     * @param record Current game state
     * @param sessionId The session identifier for pending state tracking
     * @return Updated game state (possibly with opponent's move applied)
     */
    GameRecord maybeResolveAuto(GameRecord record, String sessionId) {
        // Reset the auto-applied flag
        autoApplied = False;

        // Check if it's opponent's turn
        if (!isOpponentPending(record)) {
            pendingActiveMap.put(sessionId, False);
            return record;
        }

        Time now = clock.now;
        Boolean pendingActive = pendingActiveMap.getOrDefault(sessionId, False);
        
        // Start the thinking timer if not already started
        if (!pendingActive) {
            pendingActiveMap.put(sessionId, True);
            pendingStartMap.put(sessionId, now);
            return record;
        }

        // Check if enough time has elapsed
        Time pendingStart = pendingStartMap.getOrDefault(sessionId, now);
        Duration waited = now - pendingStart;
        if (waited >= moveDelay) {
            // Time's up! Make the opponent's move
            AutoResponse reply = ChessLogic.autoMove(record);
            pendingActiveMap.put(sessionId, False);
            autoApplied = True;
            return reply.record;
        }

        // Still thinking, return unchanged record
        return record;
    }

    /**
     * GET /api/validmoves/{sessionId}/{square}
     *
     * Gets all valid moves for a piece at the specified square.
     *
     * @param sessionId The unique session identifier for this browser
     * @param square The square containing the piece (e.g., "e2")
     * @return ValidMovesResponse with array of valid destination squares
     */
    @Get("validmoves/{sessionId}/{square}")
    @Produces(Json)
    ValidMovesHelper.ValidMovesResponse getValidMoves(String sessionId, String square) {
        using (schema.createTransaction()) {
            GameRecord record = ensureGame(sessionId);
            
            // Only show moves for White (player)
            if (record.turn != Color.White) {
                return new ValidMovesHelper.ValidMovesResponse(False, "Not your turn", []);
            }

            String[] moves = ValidMovesHelper.getValidMoves(record.board, square, Color.White);
            return new ValidMovesHelper.ValidMovesResponse(True, Null, moves);
        }
    }
}
