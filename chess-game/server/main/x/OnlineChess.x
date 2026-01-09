/**
 * Online Chess Module
 *
 * Handles online multiplayer chess game operations including:
 * - Room creation and management
 * - Player matchmaking and session tracking
 * - Online game state synchronization
 * - Turn-based move validation for multiplayer
 */
module OnlineChess.examples.org {
    package db import chessDB.examples.org;
    package logic import chessLogic.examples.org;
    package web import web.xtclang.org;

    import db.ChessSchema;
    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
    import db.GameMode;
    import db.OnlineGame;
    import logic.*;
    import web.*;

    /**
     * Online Game API Response Data Structure
     * 
     * Extended response for online multiplayer games.
     * Includes all game state fields plus multiplayer-specific information.
     * 
     * @param board              Array of 8 strings, each representing one rank (row) of the board
     * @param turn               Current player's turn ("White" or "Black")
     * @param status             Game status ("Ongoing", "Checkmate", or "Stalemate")
     * @param message            Human-readable status message for display
     * @param lastMove           Last move made in algebraic notation (e.g., "e2e4"), or null
     * @param playerScore        Number of opponent pieces captured by White
     * @param opponentScore      Number of player pieces captured by Black
     * @param opponentPending    True if waiting for opponent's move
     * @param roomCode           Room code for this game
     * @param playerColor        The color assigned to the requesting player ("White" or "Black")
     * @param isYourTurn         True if it's the requesting player's turn
     * @param waitingForOpponent True if waiting for a second player to join
     * @param gameMode           "SinglePlayer" or "Multiplayer"
     */
    const OnlineApiState(String[] board,
                         String turn,
                         String status,
                         String message,
                         String? lastMove,
                         Int playerScore,
                         Int opponentScore,
                         Boolean opponentPending,
                         String roomCode,
                         String playerColor,
                         Boolean isYourTurn,
                         Boolean waitingForOpponent,
                         String gameMode);

    /**
     * Room Creation Response
     * 
     * Response when a new game room is created.
     * 
     * @param roomCode   The unique room code for sharing with opponent
     * @param playerId   The session ID assigned to the creator
     * @param message    Status message
     */
    const RoomCreated(String roomCode, String playerId, String message);

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
        @Inject Clock       clock;
        @Inject Random      random;

        // Characters used for generating room codes
        static String ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        static Int ROOM_CODE_LENGTH = 6;

        /**
         * POST /api/online/create
         * 
         * Creates a new online game room.
         * The creator automatically becomes the White player.
         * Returns a room code to share with the opponent.
         * 
         * @return RoomCreated with room code and player session ID
         */
        @Post("create")
        @Produces(Json)
        RoomCreated createRoom() {
            using (schema.createTransaction()) {
                // Generate unique room code
                String roomCode = generateRoomCode();
                // Generate player session ID
                String playerId = generatePlayerId();
                // Create new game with initial board
                GameRecord baseGame = ChessLogic.resetGame();
                OnlineGame game = OnlineGame.fromGameRecord(
                    baseGame, roomCode, playerId, Null, GameMode.Multiplayer);
                // Store in database
                schema.onlineGames.put(roomCode, game);
                return new RoomCreated(roomCode, playerId, "Room created! Share the code with your opponent.");
            }
        }

        /**
         * POST /api/online/join/{roomCode}
         * 
         * Joins an existing online game room.
         * The joining player automatically becomes the Black player.
         * 
         * @param roomCode The room code to join
         * @return OnlineApiState with current game state
         */
        @Post("join/{roomCode}")
        @Produces(Json)
        OnlineApiState joinRoom(String roomCode) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    // Check if room is full
                    if (game.isFull()) {
                        return toOnlineApiState(game, "", "Room is full.");
                    }
                    // Generate player ID for the joining player
                    String playerId = generatePlayerId();
                    // Add Black player to the game
                    OnlineGame updated = new OnlineGame(
                        game.board, game.turn, game.status, game.lastMove,
                        game.playerScore, game.opponentScore, game.roomCode,
                        game.whitePlayerId, playerId, game.mode);
                    schema.onlineGames.put(roomCode, updated);
                    return toOnlineApiState(updated, playerId, "Joined the game! You are Black.");
                }
                return new OnlineApiState(
                    [], "White", "Ongoing", "Room not found.",
                    Null, 0, 0, False, roomCode, "", False, False, "Multiplayer");
            }
        }

        /**
         * GET /api/online/state/{roomCode}/{playerId}
         * 
         * Gets the current state of an online game.
         * 
         * @param roomCode The room code
         * @param playerId The requesting player's session ID
         * @return OnlineApiState with current game state
         */
        @Get("state/{roomCode}/{playerId}")
        @Produces(Json)
        OnlineApiState getState(String roomCode, String playerId) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    return toOnlineApiState(game, playerId, Null);
                }
                return new OnlineApiState(
                    [], "White", "Ongoing", "Room not found.",
                    Null, 0, 0, False, roomCode, "", False, False, "Multiplayer");
            }
        }

        /**
         * POST /api/online/reset/{roomCode}
         * 
         * Resets an online game to the initial state.
         * 
         * @param roomCode The room code
         * @return OnlineApiState with reset game state
         */
        @Post("reset/{roomCode}")
        @Produces(Json)
        OnlineApiState resetGame(String roomCode) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    GameRecord reset = ChessLogic.resetGame();
                    OnlineGame updated = new OnlineGame(
                        reset.board, reset.turn, reset.status, reset.lastMove,
                        reset.playerScore, reset.opponentScore, game.roomCode,
                        game.whitePlayerId, game.blackPlayerId, game.mode);
                    schema.onlineGames.put(roomCode, updated);
                    return toOnlineApiState(updated, game.whitePlayerId, "Game reset!");
                }
                return new OnlineApiState(
                    [], "White", "Ongoing", "Room not found.",
                    Null, 0, 0, False, roomCode, "", False, False, "Multiplayer");
            }
        }

        /**
         * POST /api/online/move/{roomCode}/{playerId}
         * 
         * Makes a move in an online game.
         * Validates that it's the player's turn before applying the move.
         * 
         * @param roomCode The room code
         * @param playerId The moving player's session ID
         * @param from     Source square (e.g., "e2")
         * @param target   Destination square (e.g., "e4")
         * @return OnlineApiState with updated game state or error message
         */
        @Post("move/{roomCode}/{playerId}")
        @Produces(Json)
        OnlineApiState makeMove(String roomCode, String playerId, String from, String target) {
            using (schema.createTransaction()) {
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    // Verify game has both players
                    if (!game.isFull()) {
                        return toOnlineApiState(game, playerId, "Waiting for opponent to join.");
                    }
                    // Verify it's this player's turn
                    Color? playerColor = game.getPlayerColor(playerId);
                    if (playerColor == Null) {
                        return toOnlineApiState(game, playerId, "You are not a player in this game.");
                    }
                    if (playerColor != game.turn) {
                        return toOnlineApiState(game, playerId, "It's not your turn.");
                    }
                    // Apply the move using existing game logic
                    GameRecord record = game.toGameRecord();
                    MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                    if (!result.ok) {
                        return toOnlineApiState(game, playerId, result.message);
                    }
                    // Update the online game with the new state
                    OnlineGame updated = new OnlineGame(
                        result.record.board, result.record.turn, result.record.status, result.record.lastMove,
                        result.record.playerScore, result.record.opponentScore, game.roomCode,
                        game.whitePlayerId, game.blackPlayerId, game.mode);
                    schema.onlineGames.put(roomCode, updated);
                    return toOnlineApiState(updated, playerId, Null);
                }
                return new OnlineApiState(
                    [], "White", "Ongoing", "Room not found.",
                    Null, 0, 0, False, roomCode, "", False, False, "Multiplayer");
            }
        }

        /**
         * POST /api/online/leave/{roomCode}/{playerId}
         * 
         * Leaves an online game. If a player leaves, the game is deleted.
         * 
         * @param roomCode The room code
         * @param playerId The leaving player's session ID
         * @return OnlineApiState confirming the player left
         */
        @Post("leave/{roomCode}/{playerId}")
        @Produces(Json)
        OnlineApiState leaveGame(String roomCode, String playerId) {
            using (schema.createTransaction()) {
                // Look up the room and remove it if found
                if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                    // Remove the game when a player leaves
                    schema.onlineGames.remove(roomCode);
                }
                return new OnlineApiState(
                    [], "White", "Ongoing", "You left the game. The room has been closed.",
                    Null, 0, 0, False, roomCode, "", False, False, "Multiplayer");
            }
        }

        // ----- Helper Methods ------------------------------------------------------

        /**
         * Generate a unique 6-character room code.
         */
        String generateRoomCode() {
            StringBuffer code = new StringBuffer(ROOM_CODE_LENGTH);
            for (Int i : 0 ..< ROOM_CODE_LENGTH) {
                Int idx = random.int(ROOM_CODE_CHARS.size);
                code.append(ROOM_CODE_CHARS[idx]);
            }
            String result = code.toString();
            // Ensure uniqueness (regenerate if code exists)
            if (schema.onlineGames.contains(result)) {
                return generateRoomCode();
            }
            return result;
        }

        /**
         * Generate a unique player session ID.
         */
        String generatePlayerId() {
            StringBuffer id = new StringBuffer(16);
            for (Int i : 0 ..< 16) {
                Int idx = random.int(ROOM_CODE_CHARS.size);
                id.append(ROOM_CODE_CHARS[idx]);
            }
            return id.toString();
        }

        /**
         * Convert OnlineGame to API response format.
         */
        OnlineApiState toOnlineApiState(OnlineGame game, String playerId, String? message) {
            Color? playerColor = game.getPlayerColor(playerId);
            String colorStr = playerColor?.toString() : "Spectator";
            Boolean isYourTurn = playerColor != Null && playerColor == game.turn && !game.isWaitingForOpponent();
            String detail = message ?: describeOnlineState(game, playerId);
            return new OnlineApiState(
                ChessLogic.boardRows(game.board),
                game.turn.toString(),
                game.status.toString(),
                detail,
                game.lastMove,
                game.playerScore,
                game.opponentScore,
                !isYourTurn && game.isFull() && game.status == GameStatus.Ongoing,
                game.roomCode,
                colorStr,
                isYourTurn,
                game.isWaitingForOpponent(),
                game.mode.toString());
        }

        /**
         * Generate human-readable description of online game state.
         */
        String describeOnlineState(OnlineGame game, String playerId) {
            // Check for game over
            switch (game.status) {
            case GameStatus.Checkmate:
                Color? playerColor = game.getPlayerColor(playerId);
                if (playerColor == Null) {
                    return "Game over - Checkmate!";
                }
                Boolean playerWon = game.turn != playerColor;
                return playerWon ? "Checkmate! You win!" : "Checkmate. You lost.";

            case GameStatus.Stalemate:
                return "Stalemate - It's a draw!";

            default:
                break;
            }

            // Waiting for opponent
            if (game.isWaitingForOpponent()) {
                return $"Waiting for opponent to join. Share room code: {game.roomCode}";
            }

            // Normal gameplay
            Color? playerColor = game.getPlayerColor(playerId);
            if (playerColor == Null) {
                return $"{game.turn}'s turn.";
            }

            if (playerColor == game.turn) {
                String? move = game.lastMove;
                return move == Null ? "Your move." : $"Opponent moved {move}. Your move.";
            } else {
                return "Waiting for opponent's move...";
            }
        }
    }
}
