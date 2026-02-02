/**
 * Chess Database Schema Module
 * 
 * This module defines the database schema and data models for the chess game.
 * It uses the Object-Oriented Database (OODB) framework to persist game state.
 * 
 * All models have been organized into separate files for better maintainability:
 * - models/: Core data models (Color, GameStatus, GameMode, GameRecord, etc.)
 * - base/: Base piece class
 * - pieces/: Individual piece implementations (Pawn, Knight, Bishop, etc.)
 * - types/: Type definitions and enumerations (PieceType)
 * - factory/: Factory classes for creating pieces
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

    // ===== Import Models =====
    import models.Color;
    import models.GameStatus;
    import models.GameMode;
    import models.CastlingRights;
    import models.MoveHistoryEntry;
    import models.TimeControl;
    import models.GameRecord;
    import models.OnlineGame;
    import models.ChatMessage;

    // ===== Import Base Classes =====
    import base.Piece;

    // ===== Import Piece Implementations =====
    import pieces.Pawn;
    import pieces.Knight;
    import pieces.Bishop;
    import pieces.Rook;
    import pieces.Queen;
    import pieces.King;

    // ===== Import Types =====
    import types.PieceType;

    // ===== Import Factory =====
    import factory.PieceFactory;

    // ===== Database Schema =====
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
}
