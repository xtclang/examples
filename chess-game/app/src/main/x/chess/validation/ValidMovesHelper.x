import db.models.CastlingRights;

/**
 * ValidMoves Helper Service
 *
 * Provides functionality to get all valid moves for a piece on the board.
 * This is used by the UI to show move indicators.
 */
service ValidMovesHelper {
    /**
     * Get all valid destination squares for a piece at the given position.
     * 
     * @param board The current board state (64-character string)
     * @param from The source square (e.g., "e2")
     * @param turn The current player's color
     * @param castlingRights Which castling moves are still legal (optional)
     * @param enPassantTarget Square where en passant capture is possible (optional)
     * @return Array of valid destination squares in algebraic notation
     */
    static String[] getValidMoves(String board, String from, Color turn,
                                   CastlingRights? castlingRights = Null,
                                   String? enPassantTarget = Null) {
        // Parse the source square
        Int fromPos = BoardUtils.parseSquare(from);
        if (fromPos < 0) {
            return [];
        }

        Char[] boardArray = BoardUtils.cloneBoard(board);
        Char piece = boardArray[fromPos];

        // Check if there's a piece and it belongs to the current player
        if (piece == '.' || BoardUtils.colorOf(piece) != turn) {
            return [];
        }

        // Use default castling rights if not provided
        CastlingRights rights = castlingRights ?: new CastlingRights();

        // Find all valid destination squares
        String[] validMoves = new Array<String>();
        for (Int toPos : 0 ..< 64) {
            // Skip if same square
            if (toPos == fromPos) {
                continue;
            }

            // Check if this would capture own piece
            Char target = boardArray[toPos];
            if (target != '.' && BoardUtils.colorOf(target) == turn) {
                continue;
            }

            // Check if move is legal for this piece
            if (!PieceValidator.isLegal(piece, fromPos, toPos, boardArray, rights, enPassantTarget)) {
                continue;
            }

            // Check if move leaves king in check
            if (!CheckDetection.isMoveLegalWithCheck(boardArray, fromPos, toPos, turn)) {
                continue;
            }

            validMoves.add(BoardUtils.toAlgebraic(toPos));
        }

        return validMoves.freeze(inPlace=True);
    }

    /**
     * ValidMovesResponse - API response containing valid moves for a piece
     */
    static const ValidMovesResponse(Boolean success,
                                    String? error,
                                    String[] validMoves) {}
}
