import db.models.Color;
import db.models.CastlingRights;

/**
 * Piece Movement Validator
 * This module handles move validation for each piece type:
 * - Pawns, Knights, Bishops, Rooks, Queens, Kings
 * - Path checking for sliding pieces
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
     * Delegates to DirectionUtils for implementation.
     */
    static Boolean isPathClear(Int from, Int to, Char[] board) {
        return DirectionUtils.isPathClear(from, to, board);
    }

    // ----- Piece-Specific Validation -------------------------------------------------

    /**
     * Validate pawn move (including en passant).
     */
    static Boolean isValidPawnMove(Char piece, Int from, Int to, Char[] board, String? enPassantTarget) {
        Boolean isWhite = 'A' <= piece <= 'Z';
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
            if (fileDiff == 1) {
                // Regular capture
                if (target != '.') {
                    return True;
                }
                // En passant capture
                if (enPassantTarget != Null) {
                    String targetSquare = BoardUtils.toAlgebraic(to);
                    if (targetSquare == enPassantTarget) {
                        return True;
                    }
                }
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
        return DirectionUtils.isSameDiagonal(from, to) && isPathClear(from, to, board);
    }

    /**
     * Validate rook move (horizontal or vertical).
     */
    static Boolean isValidRookMove(Int from, Int to, Char[] board) {
        return DirectionUtils.isStraightLine(from, to) && isPathClear(from, to, board);
    }

    /**
     * Validate queen move (rook + bishop).
     */
    static Boolean isValidQueenMove(Int from, Int to, Char[] board) {
        return isValidRookMove(from, to, board) || isValidBishopMove(from, to, board);
    }

    /**
     * Validate king move (one square in any direction or castling).
     */
    static Boolean isValidKingMove(Int from, Int to) {
        return BoardUtils.getDistance(from, to) == 1;
    }

    /**
     * Check if castling move is legal.
     * @param color The color of the king
     * @param from Source square (king's position)
     * @param to Destination square (king's target)
     * @param board Current board state
     * @param castlingRights Which castling moves are still allowed
     */
    static Boolean isValidCastling(Color color, Int from, Int to, Char[] board, CastlingRights castlingRights) {
        Int fromFile = BoardUtils.getFile(from);
        Int toFile = BoardUtils.getFile(to);
        Int fromRank = BoardUtils.getRank(from);
        Int toRank = BoardUtils.getRank(to);

        // Must be on same rank
        if (fromRank != toRank) {
            return False;
        }

        // King must move exactly 2 squares horizontally
        Int fileDiff = toFile - fromFile;
        if (fileDiff.abs() != 2) {
            return False;
        }

        Boolean isKingside = fileDiff > 0;
        
        // Check castling rights
        if (color == White) {
            if (fromRank != 7 || fromFile != 4) {
                return False; // White king must be on e1
            }
            if (isKingside && !castlingRights.whiteKingside) {
                return False;
            }
            if (!isKingside && !castlingRights.whiteQueenside) {
                return False;
            }
        } else {
            if (fromRank != 0 || fromFile != 4) {
                return False; // Black king must be on e8
            }
            if (isKingside && !castlingRights.blackKingside) {
                return False;
            }
            if (!isKingside && !castlingRights.blackQueenside) {
                return False;
            }
        }

        // Check path is clear
        Int step = isKingside ? 1 : -1;
        Int rookFile = isKingside ? 7 : 0;
        Int rookSquare = fromRank * 8 + rookFile;
        
        // Verify rook is present
        Char expectedRook = color == White ? 'R' : 'r';
        if (board[rookSquare] != expectedRook) {
            return False;
        }

        // Check squares between king and rook are empty
        for (Int file = fromFile + step; file != rookFile; file += step) {
            if (board[fromRank * 8 + file] != '.') {
                return False;
            }
        }

        // Additional castling legality checks:
        // 1) The king must not start in check.
        // 2) The king must not pass through or land on an attacked square.
        Color opponentColor = color == White ? Black : White;

        // The king moves horizontally from fromFile to toFile in steps of `step`.
        // Check every square the king occupies during castling: start, intermediate, and destination.
        for (Int file = fromFile; ; file += step) {
            Int square = fromRank * 8 + file;
            if (CheckDetection.isSquareAttacked(square, board, opponentColor)) {
                return False;
            }
            if (file == toFile) {
                break;
            }
        }

        return True;
    }

    // ----- Main Validation Entry Point -------------------------------------------------

    /**
     * Check if a move is legal for the given piece.
     * @param piece The piece to move
     * @param from Source square
     * @param to Destination square
     * @param board Current board state
     * @param castlingRights Which castling moves are still legal (optional)
     * @param enPassantTarget En passant target square (optional)
     */
    static Boolean isLegal(Char piece, Int from, Int to, Char[] board,
                          CastlingRights? castlingRights = Null, String? enPassantTarget = Null) {
        switch (piece.lowercase) {
            case 'p':
                return isValidPawnMove(piece, from, to, board, enPassantTarget);

            case 'n':
                return isValidKnightMove(from, to);

            case 'b':
                return isValidBishopMove(from, to, board);

            case 'r':
                return isValidRookMove(from, to, board);

            case 'q':
                return isValidQueenMove(from, to, board);

            case 'k':
                // Check regular king move
                if (isValidKingMove(from, to)) {
                    return True;
                }
                // Check castling
                if (castlingRights != Null) {
                    Color color = BoardUtils.colorOf(piece);
                    return isValidCastling(color, from, to, board, castlingRights);
                }
                return False;

            default:
                return False;
        }
    }

}

