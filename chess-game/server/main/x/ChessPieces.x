/**
 * Chess Piece Move Validation Module
 *
 * This module handles move validation for each piece type:
 * - Pawns, Knights, Bishops, Rooks, Queens, Kings
 * - Path checking for sliding pieces
 */
module ChessPieces.examples.org {
    package board import ChessBoard.examples.org;
    import board.BoardUtils;

    /**
     * Piece Movement Validator
     */
    service PieceValidator {
        // ----- Piece Type Detection -------------------------------------------------

        static Boolean isPawn(Char piece) = piece == 'p' || piece == 'P';
        static Boolean isKnight(Char piece) = piece == 'n' || piece == 'N';
        static Boolean isBishop(Char piece) = piece == 'b' || piece == 'B';
        static Boolean isRook(Char piece) = piece == 'r' || piece == 'R';
        static Boolean isQueen(Char piece) = piece == 'q' || piece == 'Q';
        static Boolean isKing(Char piece) = piece == 'k' || piece == 'K';

        // ----- Path Checking -------------------------------------------------

        /**
         * Check if path is clear for sliding pieces (rook, bishop, queen).
         */
        static Boolean isPathClear(Int from, Int to, Char[] board) {
            Int step = calculateStep(from, to);
            if (step == 0) {
                return False;
            }
            Int current = from + step;
            while (current != to) {
                if (board[current] != '.') {
                    return False;
                }
                current += step;
            }
            return True;
        }

        /**
         * Calculate step increment for moving from 'from' to 'to'.
         */
        static Int calculateStep(Int from, Int to) {
            Int diff = to - from;
            Int fileFrom = BoardUtils.getFile(from);
            Int fileTo = BoardUtils.getFile(to);
            Int rankFrom = BoardUtils.getRank(from);
            Int rankTo = BoardUtils.getRank(to);

            // Horizontal movement
            if (rankFrom == rankTo) {
                return diff > 0 ? 1 : -1;
            }
            // Vertical movement
            if (fileFrom == fileTo) {
                return diff > 0 ? 8 : -8;
            }
            // Diagonal movement
            Int fileDiff = (fileTo - fileFrom).abs();
            Int rankDiff = (rankTo - rankFrom).abs();
            if (fileDiff == rankDiff) {
                if (diff > 0) {
                    return fileTo > fileFrom ? 9 : 7;
                } else {
                    return fileTo > fileFrom ? -7 : -9;
                }
            }
            return 0;
        }

        // ----- Piece-Specific Validation -------------------------------------------------

        /**
         * Validate pawn move.
         */
        static Boolean isValidPawnMove(Char piece, Int from, Int to, Char[] board) {
            Boolean isWhite = piece >= 'A' && piece <= 'Z';
            Int direction = isWhite ? -8 : 8;
            Int startRank = isWhite ? 6 : 1;
            Int diff = to - from;

            Int fileFrom = BoardUtils.getFile(from);
            Int fileTo = BoardUtils.getFile(to);
            Int rankFrom = BoardUtils.getRank(from);

            Char target = board[to];

            // Forward move (one square)
            if (diff == direction && target == '.' && fileFrom == fileTo) {
                return True;
            }
            // Forward move (two squares from start)
            if (diff == direction * 2 && target == '.' && rankFrom == startRank && 
                fileFrom == fileTo && board[from + direction] == '.') {
                return True;
            }
            // Diagonal capture
            Int fileDiff = (fileTo - fileFrom).abs();
            if (diff == direction + 1 || diff == direction - 1) {
                if (fileDiff == 1 && target != '.') {
                    return True;
                }
            }
            return False;
        }

        /**
         * Validate knight move (L-shape).
         */
        static Boolean isValidKnightMove(Int from, Int to) {
            Int fileFrom = BoardUtils.getFile(from);
            Int fileTo = BoardUtils.getFile(to);
            Int rankFrom = BoardUtils.getRank(from);
            Int rankTo = BoardUtils.getRank(to);

            Int fileDiff = (fileTo - fileFrom).abs();
            Int rankDiff = (rankTo - rankFrom).abs();

            return (fileDiff == 2 && rankDiff == 1) || (fileDiff == 1 && rankDiff == 2);
        }

        /**
         * Validate bishop move (diagonal).
         */
        static Boolean isValidBishopMove(Int from, Int to, Char[] board) {
            Int fileFrom = BoardUtils.getFile(from);
            Int fileTo = BoardUtils.getFile(to);
            Int rankFrom = BoardUtils.getRank(from);
            Int rankTo = BoardUtils.getRank(to);

            Int fileDiff = (fileTo - fileFrom).abs();
            Int rankDiff = (rankTo - rankFrom).abs();

            return fileDiff == rankDiff && fileDiff > 0 && isPathClear(from, to, board);
        }

        /**
         * Validate rook move (horizontal or vertical).
         */
        static Boolean isValidRookMove(Int from, Int to, Char[] board) {
            Int fileFrom = BoardUtils.getFile(from);
            Int fileTo = BoardUtils.getFile(to);
            Int rankFrom = BoardUtils.getRank(from);
            Int rankTo = BoardUtils.getRank(to);

            Boolean sameFile = fileFrom == fileTo;
            Boolean sameRank = rankFrom == rankTo;

            return (sameFile || sameRank) && from != to && isPathClear(from, to, board);
        }

        /**
         * Validate queen move (rook + bishop).
         */
        static Boolean isValidQueenMove(Int from, Int to, Char[] board) {
            return isValidRookMove(from, to, board) || isValidBishopMove(from, to, board);
        }

        /**
         * Validate king move (one square in any direction).
         */
        static Boolean isValidKingMove(Int from, Int to) {
            return BoardUtils.getDistance(from, to) == 1;
        }

        // ----- Main Validation Entry Point -------------------------------------------------

        /**
         * Check if a move is legal for the given piece.
         */
        static Boolean isLegal(Char piece, Int from, Int to, Char[] board) {
            if (from == to) {
                return False;
            }

            if (isPawn(piece)) {
                return isValidPawnMove(piece, from, to, board);
            }
            if (isKnight(piece)) {
                return isValidKnightMove(from, to);
            }
            if (isBishop(piece)) {
                return isValidBishopMove(from, to, board);
            }
            if (isRook(piece)) {
                return isValidRookMove(from, to, board);
            }
            if (isQueen(piece)) {
                return isValidQueenMove(from, to, board);
            }
            if (isKing(piece)) {
                return isValidKingMove(from, to);
            }
            return False;
        }
    }
}
