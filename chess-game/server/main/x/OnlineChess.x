/**
 * Online Chess Logic Module
 *
 * Provides helper methods and logic for online multiplayer chess operations:
 * - Room code and player ID generation
 * - Game state conversion and formatting
 * - State description and messaging
 */
module OnlineChess.examples.org {
    package db import chessDB.examples.org;
    package logic import chessLogic.examples.org;

    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
    import db.OnlineGame;
    import logic.*;

    /**
     * OnlineChess Helper Service
     * 
     * Provides utility methods for online multiplayer chess operations.
     */
    service OnlineChessLogic {
        // Characters used for generating room codes
        static String ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        static Int ROOM_CODE_LENGTH = 6;
        static Int PLAYER_ID_LENGTH = 16;

        /**
         * Generate a 6-character room code using hash-based generation.
         */
        static String generateRoomCode(function Boolean(String) exists) {
            // Generate based on toString hashcode and retry if exists
            Int attempt = 0;
            loop: while (attempt < 100) {
                StringBuffer code = new StringBuffer(ROOM_CODE_LENGTH);
                Int hash = ("ROOM" + attempt).hashCode().abs();
                for (Int i : 0 ..< ROOM_CODE_LENGTH) {
                    Int idx = ((hash + i * 31) % ROOM_CODE_CHARS.size).abs();
                    code.append(ROOM_CODE_CHARS[idx]);
                }
                String result = code.toString();
                if (!exists(result)) {
                    return result;
                }
                attempt++;
            }
            // Fallback to a fixed pattern if all attempts fail
            return "ROOM00";
        }

        /**
         * Generate a player session ID using hash-based generation.
         */
        static String generatePlayerId() {
            StringBuffer id = new StringBuffer(PLAYER_ID_LENGTH);
            Int hash = ("PLAYER" + id.size).hashCode().abs();
            for (Int i : 0 ..< PLAYER_ID_LENGTH) {
                Int idx = ((hash + i * 97) % ROOM_CODE_CHARS.size).abs();
                id.append(ROOM_CODE_CHARS[idx]);
            }
            return id.toString();
        }

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
    }

    /**
     * Online Game API Response Data Structure
     * 
     * Extended response for online multiplayer games.
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
                         String gameMode,
                         String playerId = "");

    /**
     * Room Creation Response
     */
    const RoomCreated(String roomCode, String playerId, String message);
}
