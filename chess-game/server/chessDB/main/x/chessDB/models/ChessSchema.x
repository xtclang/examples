import oodb.RootSchema;

/**
 * Chess Database Schema Interface
 * 
 * Defines the root schema for the chess game database.
 * Extends the OODB RootSchema to provide typed access to stored data.
 * 
 * The schema maintains:
 * - A map of game records indexed by integer game IDs (legacy single-player)
 * - A map of online games indexed by room codes (multiplayer)
 * - A list of chat messages for online games
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
     * Single Player Games Map
     * 
     * Database map containing single-player games, indexed by browser session ID.
     * Each browser tab/window gets its own unique game instance.
     */
    @RO oodb.DBMap<String, GameRecord> singlePlayerGames;

    /**
     * Online Games Map
     * 
     * Database map containing online multiplayer games, indexed by room code.
     * Room codes are unique 6-character alphanumeric strings.
     */
    @RO oodb.DBMap<String, OnlineGame> onlineGames;

    /**
     * Chat Messages List
     * 
     * Database list containing all chat messages sent in online games.
     * Messages are stored in chronological order.
     */
    @RO oodb.DBMap<String, ChatMessage> chatMessages;

    /**
     * Authentication Schema
     * 
     * Provides user authentication and authorization for web access.
     * Manages user accounts, sessions, and permissions.
     */
    @RO auth.AuthSchema authSchema;
}
