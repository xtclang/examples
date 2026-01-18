/**
 * OnlineChess Helper Service
 *
 * Provides utility methods for online multiplayer chess operations.
 * Provides helper methods and logic for online multiplayer chess operations:
 * - Room code and player ID generation
 * - Game state conversion and formatting
 * - State description and messaging
 * - Game update operations
 * - Error response helpers
 */
service OnlineChessLogic {
    // Characters used for generating room codes (excluding ambiguous characters)
    static String ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static Int ROOM_CODE_LENGTH = 6;
    static Int PLAYER_ID_LENGTH = 16;

    // ----- ID Generation -------------------------------------------------

    /**
     * Generate a unique room code using random selection.
     * Uses the provided random generator and checks for collisions.
     */
    static String generateRoomCode(Random random, function Boolean(String) exists) {
        Int attempt = 0;
        loop: while (attempt < 100) {
            StringBuffer code = new StringBuffer(ROOM_CODE_LENGTH);
            for (Int i : 0 ..< ROOM_CODE_LENGTH) {
                Int idx = random.int(ROOM_CODE_CHARS.size);
                code.append(ROOM_CODE_CHARS[idx]);
            }
            String result = code.toString();
            if (!exists(result)) {
                return result;
            }
            attempt++;
        }
        // Fallback with timestamp-based generation
        return $"RM{attempt.toString()[0..4]}";
    }

    /**
     * Generate a unique player session ID using random selection.
     */
    static String generatePlayerId(Random random) {
        StringBuffer id = new StringBuffer(PLAYER_ID_LENGTH);
        for (Int i : 0 ..< PLAYER_ID_LENGTH) {
            Int idx = random.int(ROOM_CODE_CHARS.size);
            id.append(ROOM_CODE_CHARS[idx]);
        }
        return id.toString();
    }

    // ----- Game State Operations -----------------------------------------

    /**
     * Create a new online game room.
     */
    static (OnlineGame, String) createNewRoom(Random random, function Boolean(String) exists) {
        String roomCode = generateRoomCode(random, exists);
        String playerId = generatePlayerId(random);
        GameRecord baseGame = ChessLogic.resetGame();
        OnlineGame game = OnlineGame.fromGameRecord(
            baseGame, roomCode, playerId, Null, GameMode.Multiplayer);
        return (game, playerId);
    }

    /**
     * Add a second player to an existing game.
     */
    static (OnlineGame, String) addSecondPlayer(OnlineGame game, Random random) {
        String playerId = generatePlayerId(random);
        OnlineGame updated = new OnlineGame(
            game.board, game.turn, game.status, game.lastMove,
            game.playerScore, game.opponentScore, game.roomCode,
            game.whitePlayerId, playerId, game.mode);
        return (updated, playerId);
    }

    /**
     * Reset an online game to initial state while preserving players.
     */
    static OnlineGame resetOnlineGame(OnlineGame game) {
        GameRecord reset = ChessLogic.resetGame();
        return new OnlineGame(
            reset.board, reset.turn, reset.status, reset.lastMove,
            reset.playerScore, reset.opponentScore, game.roomCode,
            game.whitePlayerId, game.blackPlayerId, game.mode);
    }

    /**
     * Apply a move result to an online game.
     */
    static OnlineGame applyMoveResult(OnlineGame game, GameRecord result) {
        return new OnlineGame(
            result.board, result.turn, result.status, result.lastMove,
            result.playerScore, result.opponentScore, game.roomCode,
            game.whitePlayerId, game.blackPlayerId, game.mode);
    }

    // ----- Response Builders ---------------------------------------------

    /**
     * Convert OnlineGame to API response format.
     */
    static OnlineApiState toOnlineApiState(OnlineGame game, String playerId, String? message) {
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
            game.mode.toString(),
            playerId);
    }

    /**
     * Create an error response for room not found.
     */
    static OnlineApiState roomNotFoundError(String roomCode, String playerId) {
        return new OnlineApiState(
            [],
            "White",
            "Ongoing",
            "Room not found.",
            Null,
            0,
            0,
            False,
            roomCode,
            "",
            False,
            False,
            "Multiplayer",
            playerId);
    }

    /**
     * Create an error response for a full room.
     */
    static OnlineApiState roomFullError(OnlineGame game) {
        return toOnlineApiState(game, "", "Room is full.");
    }

    /**
     * Create a left game response.
     */
    static OnlineApiState leftGameResponse(String roomCode, String playerId) {
        return new OnlineApiState(
            [],
            "White",
            "Ongoing",
            "You left the game. The room has been closed.",
            Null,
            0,
            0,
            False,
            roomCode,
            "",
            False,
            False,
            "Multiplayer",
            playerId);
    }

    // ----- State Descriptions --------------------------------------------

    /**
     * Generate human-readable description of online game state.
     */
    static String describeOnlineState(OnlineGame game, String playerId) {
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

    // ----- Validation Helpers --------------------------------------------

    /**
     * Check if a player can make a move in the given game.
     * Returns an error message if invalid, or Null if valid.
     */
    static String? validateMoveRequest(OnlineGame game, String playerId) {
        if (!game.isFull()) {
            return "Waiting for opponent to join.";
        }

        Color? playerColor = game.getPlayerColor(playerId);
        if (playerColor == Null) {
            return "You are not a player in this game.";
        }

        if (playerColor != game.turn) {
            return "It's not your turn.";
        }

        if (game.status != GameStatus.Ongoing) {
            return "Game has already ended.";
        }

        return Null;
}

    /**
     * Online Game API Response Data Structure
     *
     * Extended response for online multiplayer games.
     */
    static const OnlineApiState(String[] board,
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
                         String gameMode,
                         String playerId = "");

    /**
     * Room Creation Response
     */
    static const RoomCreated(String roomCode, String playerId, String message);
}
