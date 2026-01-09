/**
 * Chess Game Server Module
 * 
 * This module implements a web-based chess game server using the XTC web framework.
 * It provides a RESTful API for managing chess games with both single-player (vs AI)
 * and online two-player multiplayer modes.
 * 
 * Key features:
 * - Turn-based chess gameplay with simplified rules (no castling, en-passant, or check detection)
 * - Single-player mode with automated opponent (Black player) with AI-driven move selection
 * - Online multiplayer mode with room-based matchmaking
 * - Game state persistence using the chess database schema
 * - RESTful API endpoints for moves, game state, room management, and game reset
 * - Static content serving for the web client interface
 */
@WebApp
module chess.examples.org {
    // Package imports: organize dependencies from different modules
    package db     import chessDB.examples.org;      // Database schema and data models
    package logic  import chessLogic.examples.org;   // Chess game logic and move validation
    package online import OnlineChess.examples.org;  // Online multiplayer chess logic
    package web    import web.xtclang.org;           // Web framework for HTTP handling

    // Import specific web framework components
    import web.*;
    // Import database schema and models
    import db.ChessSchema;
    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
    import db.OnlineGame;
    // Import all chess logic components
    import logic.*;
    // Import online multiplayer components
    import online.*;

    /**
     * Home Service
     * 
     * Serves the static web client (HTML, CSS, JavaScript) for the chess game.
     * All requests to the root path "/" are served with the index.html file
     * from the public directory.
     */
    @StaticContent("/", /public/index.html)
    service Home {}

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
    const ApiState(String[] board,
                   String turn,
                   String status,
                   String message,
                   String? lastMove,
                   Int playerScore,
                   Int opponentScore,
                   Boolean opponentPending);

    /**
     * OnlineChessApi Service
     * 
     * RESTful API service for online multiplayer chess game operations.
     * Provides endpoints for:
     * - Creating new game rooms
     * - Joining existing game rooms
     * - Making moves in online games
     * - Getting game state for online games
     * - Leaving/abandoning games
     * 
     * All operations use room codes and player session IDs for authentication.
     */
    @WebService("/api/online")
    service OnlineChessApi {
        // Injected dependencies
        @Inject ChessSchema schema;
        @Inject Random      random;

        /**
         * POST /api/online/create
         * 
         * Creates a new online game room. The creator becomes the White player
         * and receives a room code to share with their opponent.
         * 
         * @return RoomCreated with room code and player ID
         */
        @Post("create")
        @Produces(Json)
        RoomCreated createRoom() {
            using (schema.createTransaction()) {
                (OnlineGame game, String playerId) = OnlineChessLogic.createNewRoom(
                    random, code -> schema.onlineGames.contains(code));
                schema.onlineGames.put(game.roomCode, game);
                return new RoomCreated(game.roomCode, playerId, "Room created! Share the code with your opponent.");
            }
        }

        /**
         * POST /api/online/join/{roomCode}
         * 
         * Joins an existing game room as the Black player.
         * 
         * @param roomCode The 6-character room code to join
         * @return OnlineApiState with game state or error message
         */
        @Post("join/{roomCode}")
        @Produces(Json)
        OnlineApiState joinRoom(String roomCode) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    if (game.isFull()) {
                        return OnlineChessLogic.roomFullError(game);
                    }
                    (OnlineGame updated, String playerId) = OnlineChessLogic.addSecondPlayer(game, random);
                    schema.onlineGames.put(roomCode, updated);
                    return OnlineChessLogic.toOnlineApiState(updated, playerId, "Joined the game! You are Black.");
                }
                return OnlineChessLogic.roomNotFoundError(roomCode, "");
            }
        }

        /**
         * GET /api/online/state/{roomCode}/{playerId}
         * 
         * Retrieves the current state of an online game.
         * 
         * @param roomCode The room code identifying the game
         * @param playerId The player's session ID
         * @return OnlineApiState with current game state
         */
        @Get("state/{roomCode}/{playerId}")
        @Produces(Json)
        OnlineApiState getState(String roomCode, String playerId) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    return OnlineChessLogic.toOnlineApiState(game, playerId, Null);
                }
                return OnlineChessLogic.roomNotFoundError(roomCode, playerId);
            }
        }

        /**
         * POST /api/online/reset/{roomCode}/{playerId}
         * 
         * Resets the game to initial position while keeping both players.
         * 
         * @param roomCode The room code identifying the game
         * @param playerId The player's session ID
         * @return OnlineApiState with reset game state
         */
        @Post("reset/{roomCode}/{playerId}")
        @Produces(Json)
        OnlineApiState resetGame(String roomCode, String playerId) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    OnlineGame updated = OnlineChessLogic.resetOnlineGame(game);
                    schema.onlineGames.put(roomCode, updated);
                    return OnlineChessLogic.toOnlineApiState(updated, playerId, "Game reset!");
                }
                return OnlineChessLogic.roomNotFoundError(roomCode, playerId);
            }
        }

        /**
         * POST /api/online/move/{roomCode}/{playerId}/{from}/{target}
         * 
         * Makes a move in an online game.
         * 
         * @param roomCode The room code identifying the game
         * @param playerId The player's session ID
         * @param from     Source square in algebraic notation (e.g., "e2")
         * @param target   Destination square in algebraic notation (e.g., "e4")
         * @return OnlineApiState with updated game state or error message
         */
        @Post("move/{roomCode}/{playerId}/{from}/{target}")
        @Produces(Json)
        OnlineApiState makeMove(String roomCode, String playerId, String from, String target) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    // Validate the move request
                    if (String error ?= OnlineChessLogic.validateMoveRequest(game, playerId)) {
                        return OnlineChessLogic.toOnlineApiState(game, playerId, error);
                    }

                    // Apply the move
                    GameRecord record = game.toGameRecord();
                    MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                    if (!result.ok) {
                        return OnlineChessLogic.toOnlineApiState(game, playerId, result.message);
                    }

                    // Update and save the game
                    OnlineGame updated = OnlineChessLogic.applyMoveResult(game, result.record);
                    schema.onlineGames.put(roomCode, updated);
                    return OnlineChessLogic.toOnlineApiState(updated, playerId, Null);
                }
                return OnlineChessLogic.roomNotFoundError(roomCode, playerId);
            }
        }

        /**
         * POST /api/online/leave/{roomCode}/{playerId}
         * 
         * Leaves an online game and closes the room.
         * 
         * @param roomCode The room code identifying the game
         * @param playerId The player's session ID
         * @return OnlineApiState confirming the player has left
         */
        @Post("leave/{roomCode}/{playerId}")
        @Produces(Json)
        OnlineApiState leaveGame(String roomCode, String playerId) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    schema.onlineGames.remove(roomCode);
                }
                return OnlineChessLogic.leftGameResponse(roomCode, playerId);
            }
        }
    }
}
