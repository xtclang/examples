import OnlineChessLogic.OnlineApiState;
import OnlineChessLogic.RoomCreated;
import ChessGame.MoveOutcome;

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

    /**
     * GET /api/online/validmoves/{roomCode}/{playerId}/{square}
     *
     * Gets all valid moves for a piece at the specified square.
     *
     * @param roomCode The room code identifying the game
     * @param playerId The player's session ID
     * @param square   The square containing the piece (e.g., "e2")
     * @return ValidMovesResponse with array of valid destination squares
     */
    @Get("validmoves/{roomCode}/{playerId}/{square}")
    @Produces(Json)
    ValidMovesHelper.ValidMovesResponse getValidMoves(String roomCode, String playerId, String square) {
        using (schema.createTransaction()) {
            if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                // Check if player is in this game
                if (!game.hasPlayer(playerId)) {
                    return new ValidMovesHelper.ValidMovesResponse(False, "Not a player in this game", []);
                }

                // Get player's color
                Color? playerColor = game.getPlayerColor(playerId);
                if (playerColor == Null) {
                    return new ValidMovesHelper.ValidMovesResponse(False, "Could not determine player color", []);
                }

                // Check if it's player's turn
                if (playerColor != game.turn) {
                    return new ValidMovesHelper.ValidMovesResponse(False, "Not your turn", []);
                }

                // Get valid moves
                String[] moves = ValidMovesHelper.getValidMoves(game.board, square, playerColor);
                return new ValidMovesHelper.ValidMovesResponse(True, Null, moves);
            }
            return new ValidMovesHelper.ValidMovesResponse(False, "Room not found", []);
        }
    }
}