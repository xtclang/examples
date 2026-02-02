import db.models.CastlingRights;

/**
 * Check Detection
 * 
 * This provides functionality for detecting check, checkmate, and stalemate:
 * - Determine if a king is under attack (in check)
 * - Find all legal moves for a player (considering check)
 * - Detect checkmate (no legal moves and in check)
 * - Detect stalemate (no legal moves and not in check)
 */
@Abstract
class CheckDetection {
    /**
     * Check if a square is under attack by the opponent.
     * @param square The square to check
     * @param board Current board state
     * @param byColor The color that might be attacking the square
     */
    static Boolean isSquareAttacked(Int square, Char[] board, Color byColor) {
        // Check all squares on the board for pieces of the attacking color
        for (Int from = 0; from < 64; from++) {
            Char piece = board[from];
            if (piece == '.') {
                continue;
            }
            if (BoardUtils.colorOf(piece) != byColor) {
                continue;
            }
            // Check if this piece can attack the target square
            // Note: Pawns attack diagonally but move forward
            if (PieceValidator.isPawn(piece)) {
                if (canPawnAttack(piece, from, square)) {
                    return True;
                }
            } else {
                // For non-pawns, use regular move validation
                if (PieceValidator.isLegal(piece, from, square, board, Null, Null)) {
                    return True;
                }
            }
        }
        return False;
    }

    /**
     * Check if a pawn can attack a square (diagonal only).
     */
    static Boolean canPawnAttack(Char piece, Int from, Int to) {
        Boolean isWhite = 'A' <= piece <= 'Z';
        Int direction = isWhite ? -8 : 8;
        Int diff = to - from;
        
        Int fileFrom = BoardUtils.getFile(from);
        Int fileTo = BoardUtils.getFile(to);
        Int fileDiff = (fileTo - fileFrom).abs();
        
        return fileDiff == 1 && (diff == direction + 1 || diff == direction - 1);
    }

    /**
     * Find the king's position on the board.
     * Delegates to BoardOperations for implementation.
     */
    static Int findKing(Char[] board, Color color) {
        Char kingChar = color == White ? 'K' : 'k';
        return BoardOperations.findPiece(board, kingChar);
    }

    /**
     * Check if the king of a given color is in check.
     */
    static Boolean isInCheck(String boardStr, Color kingColor) {
        Char[] board = BoardUtils.cloneBoard(boardStr);
        Int kingPos = findKing(board, kingColor);
        if (kingPos < 0) {
            return False; // No king found
        }
        Color attackerColor = kingColor == White ? Black : White;
        return isSquareAttacked(kingPos, board, attackerColor);
    }

    /**
     * Simulate a move and check if it leaves the king in check.
     * @return True if the move is legal (doesn't leave king in check)
     */
    static Boolean isMoveLegalWithCheck(Char[] board, Int from, Int to, Color playerColor) {
        // Make a copy and simulate the move
        Char[] testBoard = BoardOperations.boardWithMove(board, from, to);
        
        String testBoardStr = BoardOperations.boardToString(testBoard);
        return !isInCheck(testBoardStr, playerColor);
    }

    /**
     * Move pair for representing legal moves.
     */
    static const MovePair(Int fromSquare, Int toSquare) {}

    /**
     * Get all legal moves for a player (excluding moves that leave king in check).
     */
    static MovePair[] getAllLegalMoves(String boardStr, Color turn,
                                        CastlingRights castlingRights,
                                        String? enPassantTarget) {
        Char[] board = BoardUtils.cloneBoard(boardStr);
        MovePair[] legalMoves = new MovePair[];
        
        // Check all possible moves
        for (Int from = 0; from < 64; from++) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != turn) {
                continue;
            }
            
            // Try all possible destination squares
            for (Int to = 0; to < 64; to++) {
                if (from == to) {
                    continue;
                }
                
                Char target = board[to];
                // Can't capture own pieces
                if (target != '.' && BoardUtils.colorOf(target) == turn) {
                    continue;
                }
                
                // Check if move is pseudo-legal (piece can move that way)
                if (!PieceValidator.isLegal(piece, from, to, board, castlingRights, enPassantTarget)) {
                    continue;
                }
                
                // Check if move leaves king in check
                if (!isMoveLegalWithCheck(board, from, to, turn)) {
                    continue;
                }
                
                legalMoves = legalMoves.addAll([new MovePair(from, to)]);
            }
        }
        
        return legalMoves;
    }

    /**
     * Check if the game is in checkmate or stalemate.
     * @return (isCheckmate, isStalemate)
     */
    static (Boolean checkmate, Boolean stalemate) checkGameEnd(String board, Color turn,
                                                                CastlingRights castlingRights,
                                                                String? enPassantTarget) {
        MovePair[] legalMoves = getAllLegalMoves(board, turn, castlingRights, enPassantTarget);
        
        if (legalMoves.size > 0) {
            return (False, False); // Game continues
        }
        
        // No legal moves
        Boolean inCheck = isInCheck(board, turn);
        if (inCheck) {
            return (True, False); // Checkmate
        } else {
            return (False, True); // Stalemate
        }
    }
}
