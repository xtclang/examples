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
    import models.ChessSchema;

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
}
