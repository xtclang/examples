import core.OnlineChessLogic.RoomCreated;
import core.OnlineChessLogic.OnlineApiState;
import core.ChessGame.MoveOutcome;
import core.ChessGame.AutoResponse;
import db.models.GameStatus;
import db.models.TimeControl;
import db.models.MoveHistoryEntry;
import validation.ValidMovesHelper;
import services.TimeControlService;
import core.ChessLogic;
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
    TimeControlService timeControlService = new TimeControlService();

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
            
            // Check for timeout before processing move (if time control is active)
            TimeControl? tcMaybe = record.timeControl;
            if (tcMaybe != Null && record.status == GameStatus.Ongoing) {
                TimeControl tc = tcMaybe.as(TimeControl);
                if (timeControlService.hasTimedOut(tc, record.turn)) {
                    // Player ran out of time
                    String resultMessage = record.turn == Color.White
                        ? "Time's up! Black wins on time."
                        : "Time's up! White wins on time.";
                    GameRecord timedOut = new GameRecord(
                        record.board, record.turn, GameStatus.Timeout,
                        record.lastMove, record.playerScore, record.opponentScore,
                        record.castlingRights, record.enPassantTarget,
                        record.moveHistory, record.timeControl, record.halfMoveClock);
                    saveGame(sessionId, timedOut);
                    return toApiState(timedOut, resultMessage, sessionId);
                }
            }
            
            try {
                // Validate and apply the human player's move
                MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                if (result.ok) {
                    // Update time control if active
                    GameRecord current = result.record;
                    if (current.timeControl != Null) {
                        TimeControl currentTc = current.timeControl.as(TimeControl);
                        Boolean isFirstMove = record.moveHistory.size == 0;
                        TimeControl updatedTc = timeControlService.updateAfterMove(
                            currentTc, record.turn, isFirstMove);
                        current = new GameRecord(
                            current.board, current.turn, current.status,
                            current.lastMove, current.playerScore, current.opponentScore,
                            current.castlingRights, current.enPassantTarget,
                            current.moveHistory, updatedTc, current.halfMoveClock);
                    }
                    
                    // Check if opponent should respond
                    current = maybeResolveAuto(current, sessionId);
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
     * @param request Optional request body with time control settings
     * @return ApiState with fresh game state and confirmation message
     */
    @Post("reset/{sessionId}")
    @Produces(Json)
    ApiState reset(String sessionId, @BodyParam ResetRequest? request = Null) {
        using (schema.createTransaction()) {
            // Remove existing game from database
            schema.singlePlayerGames.remove(sessionId);
            // Create a fresh game with initial board setup
            GameRecord resetGame = ChessLogic.resetGame();
            
            // Apply time control if specified
            if (request != Null && request.timeControlMs > 0) {
                TimeControl tc = timeControlService.create(request.timeControlMs, request.incrementMs);
                resetGame = new GameRecord(
                    resetGame.board, resetGame.turn, resetGame.status,
                    resetGame.lastMove, resetGame.playerScore, resetGame.opponentScore,
                    resetGame.castlingRights, resetGame.enPassantTarget,
                    resetGame.moveHistory, tc, resetGame.halfMoveClock);
            }
            
            // Save the new game
            schema.singlePlayerGames.put(sessionId, resetGame);
            // Clear pending move flags for this session
            pendingActiveMap.put(sessionId, False);
            autoApplied = False;
            return toApiState(resetGame, "New game started", sessionId);
        }
    }

    /**
     * Request body for resetting a game with time control.
     */
    static const ResetRequest(Int timeControlMs = 0, Int incrementMs = 0);


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
     * @param timeControl      Optional time control information for chess clocks
     * @param moveHistory      Complete history of all moves made in the game
     */
    static const ApiState(String[] board,
                   String turn,
                   String status,
                   String message,
                   String? lastMove,
                   Int playerScore,
                   Int opponentScore,
                   Boolean opponentPending,
                   TimeControl? timeControl = Null,
                   MoveHistoryEntry[] moveHistory = []);


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
        
        // Calculate adjusted time control with elapsed time subtracted
        // Only the active player's time should be counting down
        // Time does not count before first move or after game ends
        TimeControl? adjustedTc = Null;
        TimeControl? tcMaybe = record.timeControl;
        if (tcMaybe != Null) {
            TimeControl tc = tcMaybe.as(TimeControl);
            
            // Don't count time if game hasn't started (no moves made) or if game is over
            Boolean gameStarted = record.moveHistory.size > 0;
            Boolean gameOngoing = record.status == GameStatus.Ongoing;
            
            if (!gameStarted || !gameOngoing) {
                // Return stored times without subtracting elapsed
                adjustedTc = tc;
            } else {
                Int whiteRemaining = record.turn == Color.White 
                    ? timeControlService.getRemainingTime(tc, Color.White)
                    : tc.whiteTimeMs;
                Int blackRemaining = record.turn == Color.Black 
                    ? timeControlService.getRemainingTime(tc, Color.Black)
                    : tc.blackTimeMs;
                adjustedTc = new TimeControl(whiteRemaining, blackRemaining, tc.incrementMs, tc.lastMoveTime);
            }
        }
        
        // Construct API state with all game information
        return new ApiState(
                ChessLogic.boardRows(record.board),  // Board as array of 8 strings
                record.turn.toString(),               // "White" or "Black"
                record.status.toString(),             // Game status
                detail,                               // Descriptive message
                record.lastMove,                      // Last move notation (e.g., "e2e4")
                record.playerScore,                   // White's capture count
                record.opponentScore,                 // Black's capture count
                pending,                              // Is opponent thinking?
                adjustedTc,                           // Time control with current remaining time
                record.moveHistory);                  // Complete move history
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
            return record.turn == Color.White
                    ? "Checkmate! Black wins."
                    : "Checkmate! White wins.";

        case GameStatus.Stalemate:
            return "Draw by stalemate. No legal moves available.";

        case GameStatus.FiftyMoveRule:
            return "Draw by 50-move rule. No captures or pawn moves in 50 moves.";

        case GameStatus.InsufficientMaterial:
            return "Draw by insufficient material. Neither side can checkmate.";

        case GameStatus.ThreefoldRepetition:
            return "Draw by threefold repetition. Same position occurred three times.";

        case GameStatus.Timeout:
            return record.turn == Color.White
                    ? "Time's up! Black wins on time."
                    : "Time's up! White wins on time.";

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
            
            // Update time control for AI move if active (never first move - AI plays after human)
            GameRecord result = reply.record;
            TimeControl? resultTcMaybe = result.timeControl;
            if (resultTcMaybe != Null && reply.moved) {
                TimeControl resultTc = resultTcMaybe.as(TimeControl);
                TimeControl updatedTc = timeControlService.updateAfterMove(
                    resultTc, Color.Black, False);
                result = new GameRecord(
                    result.board, result.turn, result.status,
                    result.lastMove, result.playerScore, result.opponentScore,
                    result.castlingRights, result.enPassantTarget,
                    result.moveHistory, updatedTc, result.halfMoveClock);
            }
            
            return result;
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
