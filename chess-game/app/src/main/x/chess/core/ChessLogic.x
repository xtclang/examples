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
 * - ChessAPIClient: External Stockfish API for AI move selection
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
     * Apply a move with pre-computed square indices. Delegates to ChessGame.applyMove.
     */
    static GameRecord applyMove(GameRecord record, Char[] board, Int from, Int to, String? promotion) {
        return ChessGame.applyMove(record, board, from, to, promotion);
    }

    /**
     * Build SAN-style notation for a move. Delegates to ChessGame.createMoveNotation.
     */
    static String createMoveNotation(Char piece, Int from, Int to, Boolean isCapture,
                                     Char? promotedTo, Boolean givesCheck, Boolean isCheckmate,
                                     String? castleType) {
        return ChessGame.createMoveNotation(piece, from, to, isCapture, promotedTo, givesCheck, isCheckmate, castleType);
    }

    /**
     * Apply an AI opponent move with pre-computed from/to squares.
     */
    static AutoResponse autoMove(GameRecord record, Int from, Int to, String? promotion) = ChessGame.autoMove(record, from, to, promotion);

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

