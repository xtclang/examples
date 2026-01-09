/**
 * Chess Database Schema Module
 * 
 * This module defines the database schema and data models for the chess game.
 * It uses the Object-Oriented Database (OODB) framework to persist game state.
 * 
 * Key components:
 * - Color: Enumeration for player sides (White/Black)
 * - GameStatus: Enumeration for game lifecycle states
 * - GameMode: Enumeration for single-player vs multiplayer modes
 * - GameRecord: Immutable snapshot of a complete game state
 * - OnlineGame: Extended game record for online multiplayer games
 * - ChessSchema: Database schema interface defining stored data structures
 * 
 * The database stores game records indexed by integer IDs, along with
 * authentication information for web access control.
 */
@oodb.Database
module chessDB.examples.org {
    // Import authentication package for web security
    package auth import webauth.xtclang.org;
    // Import Object-Oriented Database framework
    package oodb import oodb.xtclang.org;

    /**
     * Player Color Enumeration
     * 
     * Represents which side a player controls in the chess game.
     * - White: The player (human), moves first according to chess rules
     * - Black: The opponent (AI in single-player, or second player in multiplayer)
     * 
     * This enum is also used to determine piece ownership on the board.
     */
    enum Color { White, Black }

    /**
     * Game Status Enumeration
     * 
     * Tracks the lifecycle and outcome of a chess game.
     * 
     * - Ongoing:    Game is still in progress, moves can be made
     * - Checkmate:  Game has ended because one player has no pieces left
     *               (simplified from traditional checkmate rules)
     * - Stalemate:  Game has ended in a draw because only kings remain
     *               on the board
     * 
     * Note: This implementation uses simplified win/loss conditions rather
     * than traditional chess checkmate and stalemate rules.
     */
    enum GameStatus { Ongoing, Checkmate, Stalemate }

    /**
     * Game Mode Enumeration
     * 
     * Distinguishes between different gameplay modes.
     * 
     * - SinglePlayer: Player vs AI (Black is controlled by the server)
     * - Multiplayer:  Player vs Player online (two human players)
     */
    enum GameMode { SinglePlayer, Multiplayer }

    /**
     * Game Record - Immutable Game State Snapshot
     * 
     * Represents a complete snapshot of a chess game at a specific point in time.
     * All game state is persisted in the database as GameRecord instances.
     * 
     * Board Representation:
     * The board is stored as a 64-character string in row-major order from a8 to h1:
     * - Characters 0-7:   Rank 8 (a8-h8) - Black's back rank
     * - Characters 8-15:  Rank 7 (a7-h7) - Black's pawn rank
     * - Characters 16-23: Rank 6 (a6-h6)
     * - Characters 24-31: Rank 5 (a5-h5)
     * - Characters 32-39: Rank 4 (a4-h4)
     * - Characters 40-47: Rank 3 (a3-h3)
     * - Characters 48-55: Rank 2 (a2-h2) - White's pawn rank
     * - Characters 56-63: Rank 1 (a1-h1) - White's back rank
     * 
     * Piece notation:
     * - Uppercase letters (R,N,B,Q,K,P) = White pieces
     * - Lowercase letters (r,n,b,q,k,p) = Black pieces
     * - Period (.) = Empty square
     * 
     * @param board          64-character string representing the board state
     * @param turn           Which color's turn it is to move
     * @param status         Current game status (Ongoing, Checkmate, or Stalemate)
     * @param lastMove       Last move made in algebraic notation (e.g., "e2e4"), or null if no moves yet
     * @param playerScore    Number of Black pieces captured by White (player)
     * @param opponentScore  Number of White pieces captured by Black (opponent)
     */
    const GameRecord(String board,
                     Color  turn,
                     GameStatus status = Ongoing,
                     String? lastMove = Null,
                     Int playerScore = 0,
                     Int opponentScore = 0) {}

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
                     GameMode mode = SinglePlayer) {

        /**
         * Convert OnlineGame to basic GameRecord.
         * Useful for compatibility with existing game logic.
         */
        GameRecord toGameRecord() {
            return new GameRecord(board, turn, status, lastMove, playerScore, opponentScore);
        }

        /**
         * Create an OnlineGame from a GameRecord with additional online fields.
         */
        static OnlineGame fromGameRecord(GameRecord rec, String roomCode, String whitePlayerId,
                                          String? blackPlayerId, GameMode mode) {
            return new OnlineGame(rec.board, rec.turn, rec.status, rec.lastMove,
                                   rec.playerScore, rec.opponentScore, roomCode,
                                   whitePlayerId, blackPlayerId, mode);
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

    /**
     * Chess Database Schema Interface
     * 
     * Defines the root schema for the chess game database.
     * Extends the OODB RootSchema to provide typed access to stored data.
     * 
     * The schema maintains:
     * - A map of game records indexed by integer game IDs (legacy single-player)
     * - A map of online games indexed by room codes (multiplayer)
     * - Authentication data for web access control
     * 
     * All database operations should be performed within transactions
     * to ensure data consistency.
     */
    interface ChessSchema
            extends oodb.RootSchema {
        /**
         * Stored Games Map (Legacy)
         * 
         * Database map containing all chess games, indexed by integer game ID.
         * Used for backward compatibility with single-player mode.
         */
        @RO oodb.DBMap<Int, GameRecord> games;

        /**
         * Online Games Map
         * 
         * Database map containing online multiplayer games, indexed by room code.
         * Room codes are unique 6-character alphanumeric strings.
         */
        @RO oodb.DBMap<String, OnlineGame> onlineGames;

        /**
         * Authentication Schema
         * 
         * Provides user authentication and authorization for web access.
         * Manages user accounts, sessions, and permissions.
         */
        @RO auth.AuthSchema authSchema;
    }
}
