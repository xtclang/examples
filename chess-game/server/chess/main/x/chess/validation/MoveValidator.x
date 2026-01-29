import db.models.CastlingRights;

/**
 * Move Validation Helper
 * Provides high-level move validation combining multiple validation aspects.
 * Reduces complexity in ChessGame by encapsulating validation logic.
 */
service MoveValidator {
    /**
     * Result of move validation with detailed error information.
     */
    static const ValidationResult(
        Boolean isValid,
        String? errorMessage = Null,
        Boolean leaveKingInCheck = False,
        Boolean invalidPieceMove = False,
        Boolean outOfTurn = False
    ) {
        /**
         * Create a successful validation result.
         */
        static ValidationResult success() {
            return new ValidationResult(True);
        }

        /**
         * Create a failed validation result with an error message.
         */
        static ValidationResult error(String message) {
            return new ValidationResult(False, message);
        }
    }

    /**
     * Validate a complete move with all checks.
     * Combines square validation, piece validation, turn validation, and check detection.
     * 
     * @param board Current board state
     * @param from Source square
     * @param to Destination square
     * @param turn Current player's turn
     * @param castlingRights Available castling rights
     * @param enPassantTarget Current en passant target
     * @return ValidationResult with details about success/failure
     */
    static ValidationResult validateMove(
        Char[] board,
        Int from,
        Int to,
        Color turn,
        CastlingRights castlingRights,
        String? enPassantTarget
    ) {
        // Validate square indices
        if (!BoardUtils.isValidSquare(from) || !BoardUtils.isValidSquare(to)) {
            return ValidationResult.error("Invalid square index");
        }

        // Check if source square has a piece
        Char piece = board[from];
        if (piece == '.') {
            return ValidationResult.error("No piece on source square");
        }

        // Validate turn
        if (BoardUtils.colorOf(piece) != turn) {
            return new ValidationResult(False, "Not your turn", False, False, True);
        }

        // Check if destination is occupied by own piece
        Char target = board[to];
        if (target != '.' && BoardUtils.colorOf(target) == turn) {
            return ValidationResult.error("Cannot capture your own piece");
        }

        // Validate piece-specific move
        if (!PieceValidator.isLegal(piece, from, to, board, castlingRights, enPassantTarget)) {
            return new ValidationResult(False, "Illegal move for that piece", False, True, False);
        }

        // Check if move leaves king in check
        if (!CheckDetection.isMoveLegalWithCheck(board, from, to, turn)) {
            return new ValidationResult(False, "Move leaves king in check", True, False, False);
        }

        return ValidationResult.success();
    }

    /**
     * Quick validation for AI move generation (skips some checks for performance).
     */
    static Boolean isQuickValid(
        Char[] board,
        Int from,
        Int to,
        Color turn,
        CastlingRights? castlingRights = Null,
        String? enPassantTarget = Null
    ) {
        Char piece = board[from];
        if (piece == '.' || BoardUtils.colorOf(piece) != turn) {
            return False;
        }

        Char target = board[to];
        if (target != '.' && BoardUtils.colorOf(target) == turn) {
            return False;
        }

        return PieceValidator.isLegal(piece, from, to, board, castlingRights, enPassantTarget);
    }

    /**
     * Check if a move would be a capture.
     */
    static Boolean isCapture(Char[] board, Int from, Int to) {
        return BoardOperations.isCapture(board, from, to);
    }

    /**
     * Check if a move would be a pawn promotion.
     */
    static Boolean isPromotion(Char[] board, Int from, Int to) {
        Char piece = board[from];
        if (!PieceValidator.isPawn(piece)) {
            return False;
        }
        Int toRank = BoardUtils.getRank(to);
        return (piece == 'P' && toRank == 0) || (piece == 'p' && toRank == 7);
    }

    /**
     * Check if a move would be castling.
     */
    static Boolean isCastling(Char[] board, Int from, Int to) {
        Char piece = board[from];
        if (!PieceValidator.isKing(piece)) {
            return False;
        }
        Int fileDiff = (BoardUtils.getFile(to) - BoardUtils.getFile(from)).abs();
        return fileDiff == 2;
    }

    /**
     * Check if a move would be en passant.
     */
    static Boolean isEnPassant(Char[] board, Int from, Int to, String? enPassantTarget) {
        if (enPassantTarget == Null) {
            return False;
        }
        Char piece = board[from];
        if (!PieceValidator.isPawn(piece)) {
            return False;
        }
        String toSquare = BoardUtils.toAlgebraic(to);
        Char target = board[to];
        return toSquare == enPassantTarget && target == '.';
    }
}
