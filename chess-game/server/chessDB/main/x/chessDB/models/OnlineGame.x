/**
 * Online Game Record - Extended Game State for Multiplayer
 * 
 * Extends GameRecord with additional fields required for online multiplayer:
 * - Room code for game identification and joining
 * - Player session IDs for authentication
 * - Game mode to distinguish single-player vs multiplayer
 * - Timestamps for activity tracking and cleanup
 * 
 * @param board            64-character string representing the board state
 * @param turn             Which color's turn it is to move
 * @param status           Current game status (Ongoing, Checkmate, or Stalemate)
 * @param lastMove         Last move made in algebraic notation
 * @param playerScore      Number of pieces captured by White player
 * @param opponentScore    Number of pieces captured by Black player
 * @param roomCode         Unique 6-character room code for joining (e.g., "ABC123")
 * @param whitePlayerId    Session ID of the White player (creator)
 * @param blackPlayerId    Session ID of the Black player (joiner), or null if waiting
 * @param mode             Game mode (SinglePlayer or Multiplayer)
 * @param castlingRights   Tracks which castling moves are still legal
 * @param enPassantTarget  Square where en passant capture is possible, or null
 * @param moveHistory      Complete history of all moves made in the game
 * @param timeControl      Time remaining and settings for each player
 * @param halfMoveClock    Number of half-moves since last capture or pawn move
 * @param playerLeftId     The ID of a player who left the game (if any)
 */
const OnlineGame(String board,
                 Color  turn,
                 GameStatus status = Ongoing,
                 String? lastMove = Null,
                 Int playerScore = 0,
                 Int opponentScore = 0,
                 String roomCode = "",
                 String whitePlayerId = "",
                 String? blackPlayerId = Null,
                 GameMode mode = SinglePlayer,
                 CastlingRights castlingRights = new CastlingRights(),
                 String? enPassantTarget = Null,
                 MoveHistoryEntry[] moveHistory = [],
                 TimeControl? timeControl = Null,
                 Int halfMoveClock = 0,
                 String? playerLeftId = Null) {

    /**
     * Convert OnlineGame to basic GameRecord.
     * Useful for compatibility with existing game logic.
     */
    GameRecord toGameRecord() {
        return new GameRecord(board, turn, status, lastMove, playerScore, opponentScore,
                            castlingRights, enPassantTarget, moveHistory, timeControl, halfMoveClock);
    }

    /**
     * Create an OnlineGame from a GameRecord with additional online fields.
     */
    static OnlineGame fromGameRecord(GameRecord rec,
                                      String roomCode,
                                      String whitePlayerId,
                                      String? blackPlayerId,
                                      GameMode mode) {
        return new OnlineGame(rec.board,
                                 rec.turn,
                                 rec.status,
                                 rec.lastMove,
                                 rec.playerScore,
                                 rec.opponentScore,
                                 roomCode,
                                 whitePlayerId,
                                 blackPlayerId,
                                 mode,
                                 rec.castlingRights,
                                 rec.enPassantTarget,
                                 rec.moveHistory,
                                 rec.timeControl,
                                 rec.halfMoveClock,
                                 Null);
    }

    /**
     * Check if opponent has left the game.
     */
    Boolean hasOpponentLeft(String myPlayerId) {
        if (playerLeftId == Null) {
            return False;
        }
        return playerLeftId != myPlayerId;
    }

    /**
     * Check if a player with the given session ID is in this game.
     */
    Boolean hasPlayer(String playerId) {
        return whitePlayerId == playerId || blackPlayerId == playerId;
    }

    /**
     * Get the color assigned to a player by their session ID.
     * Returns Null if the player is not in this game.
     */
    Color? getPlayerColor(String playerId) {
        if (whitePlayerId == playerId) {
            return White;
        }
        if (blackPlayerId == playerId) {
            return Black;
        }
        return Null;
    }

    /**
     * Check if the game is waiting for a second player.
     */
    Boolean isWaitingForOpponent() {
        return mode == Multiplayer && blackPlayerId == Null;
    }

    /**
     * Check if both players have joined (for multiplayer games).
     */
    Boolean isFull() {
        return mode == SinglePlayer || blackPlayerId != Null;
    }
}
