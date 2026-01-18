import OnlineChessLogic.RoomCreated;
import OnlineChessLogic.OnlineApiState;
import ChessGame.MoveOutcome;
import ChessGame.AutoResponse;
import db.MoveHistoryEntry;
import db.CastlingRights;
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
 */
@WebService("/api")
service ChessApi {
    // Injected dependencies for database access and time tracking
    @Inject ChessSchema schema;  // Database schema for game persistence
    @Inject Clock         clock; // System clock for timing opponent moves

    // Atomic properties to track opponent's pending move state
    @Atomic private Boolean pendingActive;  // True when opponent is "thinking"
    @Atomic private Time    pendingStart;   // Timestamp when opponent started thinking
    @Atomic private Boolean autoApplied;    // True if an auto-move was just applied

    // Duration to wait before opponent makes a move (3 seconds)
    @RO Duration moveDelay.get() = Duration.ofSeconds(3);

    /**
     * GET /api/state
     *
     * Retrieves the current state of the chess game including:
     * - Board position (64-character string representation)
     * - Current turn (White or Black)
     * - Game status (Ongoing, Checkmate, Stalemate)
     * - Last move made
     * - Player and opponent scores
     * - Whether opponent is currently thinking
     *
     * This endpoint also triggers automated opponent moves if sufficient
     * time has elapsed since the opponent's turn began.
     *
     * @return ApiState object containing complete game state as JSON
     */
    @Get("state")
    @Produces(Json)
    ApiState state() {
        using (schema.createTransaction()) {
            // Ensure a game exists (create default if needed)
            GameRecord record = ensureGame();
            // Check if opponent should make an automatic move
            GameRecord updated = maybeResolveAuto(record);
            // Save the game if an auto-move was applied
            if (autoApplied) {
                saveGame(updated);
            }
            // Convert to API format and return
            return toApiState(updated, Null);
        }
    }

    /**
     * POST /api/move/{from}/{target}
     *
     * Executes a player's chess move from one square to another.
     *
     * Path parameters:
     * @param from   Source square in algebraic notation (e.g., "e2")
     * @param target Destination square in algebraic notation (e.g., "e4")
     *
     * Process:
     * 1. Validates the move according to chess rules
     * 2. Applies the move if legal
     * 3. Triggers opponent's automated move if appropriate
     * 4. Updates game state including captures and status
     *
     * @return ApiState with updated game state or error message if move was illegal
     */
    @Post("move/{from}/{target}")
    @Produces(Json)
    ApiState move(String from, String target) {
        using (schema.createTransaction()) {
            // Ensure game exists
            GameRecord record = ensureGame();
            try {
                // Validate and apply the human player's move
                MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                if (result.ok) {
                    // Move was legal, check if opponent should respond
                    GameRecord current = maybeResolveAuto(result.record);
                    // Persist the updated game state
                    saveGame(current);
                    return toApiState(current, Null);
                }
                // Move was illegal, return error message
                return toApiState(result.record, result.message);
            } catch (Exception e) {
                // Handle unexpected errors gracefully
                return toApiState(record, $"Server error: {e.toString()}");
            }
        }
    }

    /**
     * POST /api/reset
     *
     * Resets the game to initial state:
     * - New board with starting piece positions
     * - White to move
     * - Scores reset to 0
     * - All pending moves cancelled
     *
     * This is useful when starting a new game or recovering from
     * an undesirable game state.
     *
     * @return ApiState with fresh game state and confirmation message
     */
    @Post("reset")
    @Produces(Json)
    ApiState reset() {
        using (schema.createTransaction()) {
            // Remove existing game from database
            schema.games.remove(gameId);
            // Create a fresh game with initial board setup
            GameRecord reset = ChessLogic.resetGame();
            // Save the new game
            schema.games.put(gameId, reset);
            // Clear all pending move flags
            pendingActive = False;
            autoApplied   = False;
            return toApiState(reset, "New game started");
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
     * The game ID used for storing/retrieving the game.
     * Currently hardcoded to 1 for single-game support.
     */
    @RO Int gameId.get() = 1;

    /**
     * Ensures a game record exists in the database.
     * If no game exists, creates a new one with default starting position.
     *
     * @return The existing or newly created GameRecord
     */
    GameRecord ensureGame() {
        // Try to get existing game, or use default if not found
        GameRecord record = schema.games.getOrDefault(gameId, ChessLogic.defaultGame());
        // If game wasn't in database, save it now
        if (!schema.games.contains(gameId)) {
            schema.games.put(gameId, record);
        }
        return record;
    }

    /**
     * Persists the game record to the database.
     *
     * @param record The GameRecord to save
     */
    void saveGame(GameRecord record) {
        schema.games.put(gameId, record);
    }

    /**
     * Converts internal GameRecord to API response format.
     *
     * @param record  The game record from database
     * @param message Optional custom message (e.g., error message)
     * @return ApiState object ready for JSON serialization
     */
    ApiState toApiState(GameRecord record, String? message = Null) {
        // Check if opponent is currently thinking
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
     * @return Updated game state (possibly with opponent's move applied)
     */
    GameRecord maybeResolveAuto(GameRecord record) {
        // Reset the auto-applied flag
        autoApplied = False;

        // Check if it's opponent's turn
        if (!isOpponentPending(record)) {
            pendingActive = False;
            return record;
        }

        Time now = clock.now;
        // Start the thinking timer if not already started
        if (!pendingActive) {
            pendingActive = True;
            pendingStart  = now;
            return record;
        }

        // Check if enough time has elapsed
        Duration waited = now - pendingStart;
        if (waited >= moveDelay) {
            // Time's up! Make the opponent's move
            AutoResponse reply = ChessLogic.autoMove(record);
            pendingActive = False;
            autoApplied   = True;
            return reply.record;
        }

        // Still thinking, return unchanged record
        return record;
    }

    /**
     * GET /api/validmoves/{square}
     *
     * Gets all valid moves for a piece at the specified square.
     *
     * @param square The square containing the piece (e.g., "e2")
     * @return ValidMovesResponse with array of valid destination squares
     */
    @Get("validmoves/{square}")
    @Produces(Json)
    ValidMovesHelper.ValidMovesResponse getValidMoves(String square) {
        using (schema.createTransaction()) {
            GameRecord record = ensureGame();
            
            // Only show moves for White (player)
            if (record.turn != Color.White) {
                return new ValidMovesHelper.ValidMovesResponse(False, "Not your turn", []);
            }

            String[] moves = ValidMovesHelper.getValidMoves(record.board, square, Color.White);
            return new ValidMovesHelper.ValidMovesResponse(True, Null, moves);
        }
    }

    /**
     * POST /api/undo
     *
     * Undoes the last move (or last two moves in single-player to undo both player and AI).
     *
     * @return ApiState with the game state after undo
     */
    @Post("undo")
    @Produces(Json)
    ApiState undo() {
        using (schema.createTransaction()) {
            GameRecord record = ensureGame();
            
            if (record.moveHistory.size == 0) {
                return toApiState(record, "No moves to undo");
            }

            // In single-player, undo both player and AI moves
            Int undoCount = record.moveHistory.size >= 2 ? 2 : 1;
            
            // Reconstruct game state from move history
            GameRecord restored = reconstructGameState(record, record.moveHistory.size - undoCount);
            saveGame(restored);
            
            return toApiState(restored, Null);
        }
    }

    /**
     * GET /api/history
     *
     * Retrieves the complete move history of the current game.
     *
     * @return HistoryResponse with all moves in standard notation
     */
    @Get("history")
    @Produces(Json)
    HistoryResponse getHistory() {
        using (schema.createTransaction()) {
            GameRecord record = ensureGame();
            return new HistoryResponse(True, record.moveHistory);
        }
    }

    /**
     * GET /api/replay/{moveNumber}
     *
     * Gets the game state at a specific move number for replay.
     *
     * @param moveNumber The move number to replay to (0 = start position)
     * @return ApiState with the game state at that point
     */
    @Get("replay/{moveNumber}")
    @Produces(Json)
    ApiState replay(Int moveNumber) {
        using (schema.createTransaction()) {
            GameRecord record = ensureGame();
            
            if (moveNumber < 0 || moveNumber > record.moveHistory.size) {
                return toApiState(record, "Invalid move number");
            }

            GameRecord replayed = reconstructGameState(record, moveNumber);
            return toApiState(replayed, Null);
        }
    }

    /**
     * Reconstruct game state up to a specific move number.
     */
    GameRecord reconstructGameState(GameRecord current, Int upToMove) {
        if (upToMove == 0) {
            return ChessLogic.defaultGame();
        }

        if (upToMove >= current.moveHistory.size) {
            return current;
        }

        // Use the board state from the move history
        MoveHistoryEntry lastMove = current.moveHistory[upToMove - 1];
        
        // Create a new game record with state up to this move
        MoveHistoryEntry[] limitedHistory = current.moveHistory[0 ..< upToMove];
        
        // Determine whose turn it is next
        Color nextTurn = lastMove.color == White ? Black : White;
        
        return new GameRecord(
            lastMove.boardAfter,
            nextTurn,
            Ongoing,
            $"{lastMove.fromSquare}{lastMove.toSquare}",
            calculateScore(limitedHistory, White),
            calculateScore(limitedHistory, Black),
            reconstructCastlingRights(limitedHistory),
            Null, // En passant target would need to be recalculated
            limitedHistory,
            current.timeControl,
            0);
    }

    /**
     * Calculate score from move history.
     */
    Int calculateScore(MoveHistoryEntry[] history, Color color) {
        Int score = 0;
        for (MoveHistoryEntry move : history) {
            if (move.color == color && move.capturedPiece != Null) {
                score++;
            }
        }
        return score;
    }

    /**
     * Reconstruct castling rights from move history.
     */
    CastlingRights reconstructCastlingRights(MoveHistoryEntry[] history) {
        Boolean whiteKingside = True;
        Boolean whiteQueenside = True;
        Boolean blackKingside = True;
        Boolean blackQueenside = True;

        for (MoveHistoryEntry move : history) {
            if (move.piece == 'K') {
                whiteKingside = False;
                whiteQueenside = False;
            } else if (move.piece == 'k') {
                blackKingside = False;
                blackQueenside = False;
            } else if (move.piece == 'R') {
                if (move.fromSquare == "h1") { whiteKingside = False; }
                if (move.fromSquare == "a1") { whiteQueenside = False; }
            } else if (move.piece == 'r') {
                if (move.fromSquare == "h8") { blackKingside = False; }
                if (move.fromSquare == "a8") { blackQueenside = False; }
            }

            // Check if rook was captured
            if (move.toSquare == "h1") { whiteKingside = False; }
            if (move.toSquare == "a1") { whiteQueenside = False; }
            if (move.toSquare == "h8") { blackKingside = False; }
            if (move.toSquare == "a8") { blackQueenside = False; }
        }

        return new CastlingRights(whiteKingside, whiteQueenside, blackKingside, blackQueenside);
    }

    /**
     * Response for history endpoint.
     */
    static const HistoryResponse(Boolean ok, MoveHistoryEntry[] moves);
}
