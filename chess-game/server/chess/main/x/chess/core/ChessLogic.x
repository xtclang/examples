// Import chess game services
import core.ChessGame.MoveOutcome;
import core.ChessGame.AutoResponse;



/**
 * ChessLogic Service - Main API
 * This service delegates to specialized modules while maintaining
 * the same public API for backward compatibility.
 * This module provides a unified interface to the chess game logic,
 * delegating to specialized modules:
 * - ChessBoard: Board utilities and notation
 * - ChessPieces: Piece-specific move validation
 * - ChessAI: AI opponent move selection
 * - ChessGame: Game state management and move application
 * This maintains backward compatibility while organizing code into
 * focused, maintainable modules.
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
    static AutoResponse autoMove(GameRecord record) = ChessGame.autoMove(record);

    /**
     * Get default starting board.
     */
    static String defaultBoard() = ChessGame.defaultBoard();

    /**
     * Create default game.
     */
    static GameRecord defaultGame() = ChessGame.defaultGame();


    /**
     * Reset game to initial state.
     */
    static GameRecord resetGame() = ChessGame.resetGame();


    /**
     * Convert board to array of row strings.
     */
    static String[] boardRows(String board) = ChessGame.boardRows(board);


}

