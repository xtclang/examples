import core.OnlineChessLogic.OnlineApiState;
import core.OnlineChessLogic.RoomCreated;
import core.OnlineChessLogic;
import core.ChessGame.MoveOutcome;
import validation.ValidMovesHelper.ValidMovesResponse;
import validation.ValidMovesHelper;
import db.models.TimeControl;
import services.TimeControlService;
import core.ChessLogic;

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
    TimeControlService timeControlService = new TimeControlService();

    /**
     * Calculate adjusted time control with actual remaining time.
     * Only the active player's time should be counting down.
     * Time does not count before first move or after game ends.
     */
    TimeControl? getAdjustedTime(OnlineGame game) {
        TimeControl? tcMaybe = game.timeControl;
        if (tcMaybe != Null) {
            TimeControl tc = tcMaybe.as(TimeControl);
            
            // Don't count time if game hasn't started (no moves made) or if game is over
            Boolean gameStarted = game.moveHistory.size > 0;
            Boolean gameOngoing = game.status == GameStatus.Ongoing;
            
            if (!gameStarted || !gameOngoing) {
                // Return stored times without subtracting elapsed
                return tc;
            }
            
            // Only subtract elapsed time from the active player's clock
            Int whiteRemaining = game.turn == Color.White 
                ? timeControlService.getRemainingTime(tc, Color.White)
                : tc.whiteTimeMs;
            Int blackRemaining = game.turn == Color.Black 
                ? timeControlService.getRemainingTime(tc, Color.Black)
                : tc.blackTimeMs;
            return new TimeControl(whiteRemaining, blackRemaining, tc.incrementMs, tc.lastMoveTime);
        }
        return Null;
    }

    /**
     * POST /api/online/create
     *
     * Creates a new online game room. The creator becomes the White player
     * and receives a room code to share with their opponent.
     *
     * @param request Optional request body with time control settings
     * @return RoomCreated with room code and player ID
     */
    @Post("create")
    @Produces(Json)
    RoomCreated createRoom(@BodyParam CreateRoomRequest? request = Null) {
        using (schema.createTransaction()) {
            TimeControl? timeCtrl = Null;
            if (request != Null && request.timeControlMs > 0) {
                timeCtrl = timeControlService.create(request.timeControlMs, request.incrementMs);
            }
            
            (OnlineGame game, String playerId) = OnlineChessLogic.createNewRoom(
                random, (String code) -> schema.onlineGames.contains(code), timeCtrl);
            schema.onlineGames.put(game.roomCode, game);
            return new RoomCreated(game.roomCode, playerId, "Room created! Share the code with your opponent.");
        }
    }

    /**
     * Request body for creating a room with time control.
     */
    static const CreateRoomRequest(Int timeControlMs = 0, Int incrementMs = 0);

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
                return OnlineChessLogic.toOnlineApiState(updated, playerId, "Joined the game! You are Black.", getAdjustedTime(updated));
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
                return OnlineChessLogic.toOnlineApiState(game, playerId, Null, getAdjustedTime(game));
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
                return OnlineChessLogic.toOnlineApiState(updated, playerId, "Game reset!", getAdjustedTime(updated));
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
                    return OnlineChessLogic.toOnlineApiState(game, playerId, error, getAdjustedTime(game));
                }
                
                // Check for timeout before processing move (if time control is active)
                TimeControl? gameTcMaybe = game.timeControl;
                if (gameTcMaybe != Null && game.status == GameStatus.Ongoing) {
                    TimeControl gameTc = gameTcMaybe.as(TimeControl);
                    if (timeControlService.hasTimedOut(gameTc, game.turn)) {
                        // Player ran out of time
                        String resulMessage = game.turn == Color.White
                            ? "Time's up! Black wins on time."
                            : "Time's up! White wins on time.";
                        OnlineGame timedOut = new OnlineGame(
                            game.board, game.turn, GameStatus.Timeout,
                            game.lastMove, game.playerScore, game.opponentScore,
                            game.roomCode, game.whitePlayerId, game.blackPlayerId, game.mode,
                            game.castlingRights, game.enPassantTarget,
                            game.moveHistory, game.timeControl, game.halfMoveClock, game.playerLeftId);
                        schema.onlineGames.put(roomCode, timedOut);
                        return OnlineChessLogic.toOnlineApiState(timedOut, playerId, resulMessage, getAdjustedTime(timedOut));
                    }
                }

                // Apply the move
                GameRecord record = game.toGameRecord();
                Color movedColor = game.turn;
                MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                if (!result.ok) {
                    return OnlineChessLogic.toOnlineApiState(game, playerId, result.message, getAdjustedTime(game));
                }
                
                // Update time control if active
                GameRecord updatedRecord = result.record;
                TimeControl? recordTcMaybe = updatedRecord.timeControl;
                if (recordTcMaybe != Null) {
                    TimeControl recordTc = recordTcMaybe.as(TimeControl);
                    Boolean isFirstMove = game.moveHistory.size == 0;
                    TimeControl updatedTc = timeControlService.updateAfterMove(
                        recordTc, movedColor, isFirstMove);
                    updatedRecord = new GameRecord(
                        updatedRecord.board, updatedRecord.turn, updatedRecord.status,
                        updatedRecord.lastMove, updatedRecord.playerScore, updatedRecord.opponentScore,
                        updatedRecord.castlingRights, updatedRecord.enPassantTarget,
                        updatedRecord.moveHistory, updatedTc, updatedRecord.halfMoveClock);
                }

                // Update and save the game
                OnlineGame updated = OnlineChessLogic.applyMoveResult(game, updatedRecord);
                schema.onlineGames.put(roomCode, updated);
                return OnlineChessLogic.toOnlineApiState(updated, playerId, Null, getAdjustedTime(updated));
            }
            return OnlineChessLogic.roomNotFoundError(roomCode, playerId);
        }
    }

    /**
     * POST /api/online/leave/{roomCode}/{playerId}
     *
     * Leaves an online game. Marks the player as left so opponent knows.
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
                // Mark the player as having left
                OnlineGame updatedGame = new OnlineGame(
                    game.board,
                    game.turn,
                    game.status,
                    game.lastMove,
                    game.playerScore,
                    game.opponentScore,
                    game.roomCode,
                    game.whitePlayerId,
                    game.blackPlayerId,
                    game.mode,
                    game.castlingRights,
                    game.enPassantTarget,
                    game.moveHistory,
                    game.timeControl,
                    game.halfMoveClock,
                    playerId
                );
                schema.onlineGames.put(roomCode, updatedGame);
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
    ValidMovesResponse getValidMoves(String roomCode, String playerId, String square) {
        using (schema.createTransaction()) {
            if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                // Check if player is in this game
                if (!game.hasPlayer(playerId)) {
                    return new ValidMovesResponse(False, "Not a player in this game", []);
                }

                // Get player's color
                Color? playerColor = game.getPlayerColor(playerId);
                if (playerColor == Null) {
                    return new ValidMovesResponse(False, "Could not determine player color", []);
                }

                // Check if it's player's turn
                if (playerColor != game.turn) {
                    return new ValidMovesResponse(False, "Not your turn", []);
                }

                // Get valid moves
                String[] moves = ValidMovesHelper.getValidMoves(game.board, square, playerColor,
                                                               game.castlingRights, game.enPassantTarget);
                return new ValidMovesResponse(True, Null, moves);
            }
            return new ValidMovesResponse(False, "Room not found", []);
        }
    }
}