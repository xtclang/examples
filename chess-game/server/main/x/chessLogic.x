/**
 * Chess Game Logic Module (Main Entry Point)
 *
 * This module provides a unified interface to the chess game logic,
 * delegating to specialized modules:
 * - ChessBoard: Board utilities and notation
 * - ChessPieces: Piece-specific move validation
 * - ChessAI: AI opponent move selection
 * - ChessGame: Game state management and move application
 *
 * This maintains backward compatibility while organizing code into
 * focused, maintainable modules.
 */
module chessLogic.examples.org {
    // Import database package for data models
    package db import chessDB.examples.org;
    
    // Import chess logic modules
    package game import ChessGame.examples.org;

    // Import database models
    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
    
    // Import chess game services
    import game.*;

    /**
     * Move Outcome - Result of attempting a move
     * Re-exported from ChessGame module for backward compatibility
     */
    typedef game.MoveOutcome as MoveOutcome;

    /**
     * Auto Response - Result of AI move
     * Re-exported from ChessGame module for backward compatibility
     */
    typedef game.AutoResponse as AutoResponse;

    /**
     * ChessLogic Service - Main API
     *
     * This service delegates to specialized modules while maintaining
     * the same public API for backward compatibility.
     */
    service ChessLogic {
        /**
         * Apply a human player's move.
         */
        static MoveOutcome applyHumanMove(GameRecord record, String fromSquare, String toSquare, String? promotion = Null) {
            return ChessGame.applyHumanMove(record, fromSquare, toSquare, promotion);
        }

        /**
         * Generate AI opponent move.
         */
        static AutoResponse autoMove(GameRecord record) {
            return ChessGame.autoMove(record);
        }

        /**
         * Get default starting board.
         */
        static String defaultBoard() {
            return ChessGame.defaultBoard();
        }

        /**
         * Create default game.
         */
        static GameRecord defaultGame() {
            return ChessGame.defaultGame();
        }

        /**
         * Reset game to initial state.
         */
        static GameRecord resetGame() {
            return ChessGame.resetGame();
        }

        /**
         * Convert board to array of row strings.
         */
        static String[] boardRows(String board) {
            return ChessGame.boardRows(board);
        }
    }
}
