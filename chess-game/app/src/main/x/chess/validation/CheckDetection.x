import db.models.CastlingRights;
import db.models.MoveHistoryEntry;

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
    // Knight jumps and the eight king/queen directions, as (rank, file) offsets
    static Int[] KNIGHT_DR = [-2, -2, -1, -1,  1,  1,  2,  2];
    static Int[] KNIGHT_DC = [-1,  1, -2,  2, -2,  2, -1,  1];
    static Int[] RAY_DR    = [-1, -1, -1,  0,  0,  1,  1,  1];
    static Int[] RAY_DC    = [-1,  0,  1, -1,  1, -1,  0,  1];

    /**
     * Check if a square is under attack by the given color.
     *
     * Looks outward from the square -- pawn and knight offsets, then the eight rays -- rather than
     * asking every attacking piece whether it can reach the square. That is at most about 30
     * squares read, instead of a move validation per enemy piece, and it sits inside the loop that
     * tests every candidate move for check, so it dominates the cost of generating legal moves.
     *
     * @param square The square to check
     * @param board Current board state
     * @param byColor The color that might be attacking the square
     */
    static Boolean isSquareAttacked(Int square, Char[] board, Color byColor) {
        Int     row   = BoardUtils.getRank(square);
        Int     col   = BoardUtils.getFile(square);
        Boolean white = byColor == White;

        Char pawn   = white ? 'P' : 'p';
        Char knight = white ? 'N' : 'n';
        Char bishop = white ? 'B' : 'b';
        Char rook   = white ? 'R' : 'r';
        Char queen  = white ? 'Q' : 'q';
        Char king   = white ? 'K' : 'k';

        // White pawns attack up the board (toward lower indices), so an attacking white pawn sits
        // one rank below the target; an attacking black pawn sits one rank above it.
        Int pawnRow = white ? row + 1 : row - 1;
        if (0 <= pawnRow < 8) {
            if (col > 0 && board[pawnRow * 8 + col - 1] == pawn) {
                return True;
            }
            if (col < 7 && board[pawnRow * 8 + col + 1] == pawn) {
                return True;
            }
        }

        for (Int i : 0 ..< 8) {
            Int r = row + KNIGHT_DR[i];
            Int c = col + KNIGHT_DC[i];
            if (0 <= r < 8 && 0 <= c < 8 && board[r * 8 + c] == knight) {
                return True;
            }
        }

        for (Int d : 0 ..< 8) {
            Int     dr       = RAY_DR[d];
            Int     dc       = RAY_DC[d];
            Char    slider   = dr == 0 || dc == 0 ? rook : bishop;
            Boolean adjacent = True;
            Int     r        = row + dr;
            Int     c        = col + dc;
            while (0 <= r < 8 && 0 <= c < 8) {
                Char piece = board[r * 8 + c];
                if (piece != '.') {
                    if (piece == queen || piece == slider || (adjacent && piece == king)) {
                        return True;
                    }
                    break;
                }
                adjacent = False;
                r += dr;
                c += dc;
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
    static Boolean isInCheck(Char[] board, Color kingColor) {
        Int kingPos = findKing(board, kingColor);
        if (kingPos < 0) {
            return False; // No king found
        }
        Color attackerColor = kingColor == White ? Black : White;
        return isSquareAttacked(kingPos, board, attackerColor);
    }

    /**
     * Check if the king of a given color is in check.
     */
    static Boolean isInCheck(String boardStr, Color kingColor) {
        return isInCheck(BoardUtils.cloneBoard(boardStr), kingColor);
    }

    /**
     * Simulate a move and check if it leaves the king in check.
     * @return True if the move is legal (doesn't leave king in check)
     */
    static Boolean isMoveLegalWithCheck(Char[] board, Int from, Int to, Color playerColor) {
        // Make a copy and simulate the move
        Char[] testBoard = BoardOperations.boardWithMove(board, from, to);

        return !isInCheck(testBoard.freeze(), playerColor);
    }

    /**
     * Move pair for representing legal moves.
     */
    static const MovePair(Int fromSquare, Int toSquare) {}

    /**
     * Get all legal moves for a player (excluding moves that leave king in check).
     *
     * @param firstOnly  stop at the first legal move found. Enough when the caller only needs to
     *                   know whether a legal move exists (checkmate/stalemate detection), and far
     *                   cheaper: each candidate costs a full king-safety scan.
     */
    static MovePair[] getAllLegalMoves(String boardStr, Color turn,
                                        CastlingRights castlingRights,
                                        String? enPassantTarget,
                                        Boolean firstOnly = False) {
        Char[] board = BoardUtils.cloneBoard(boardStr);
        MovePair[] legalMoves = new MovePair[];
        
        // Check all possible moves
        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != turn) {
                continue;
            }
            
            // Try all possible destination squares
            for (Int to : 0 ..< 64) {
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
                if (firstOnly) {
                    return legalMoves;
                }
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
        MovePair[] legalMoves = getAllLegalMoves(board, turn, castlingRights, enPassantTarget, True);
        
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

    // ----- Draw Detection -------------------------------------------------

    /**
     * Check if there is insufficient material to deliver checkmate.
     * Covers these cases:
     *   - King vs King
     *   - King + Bishop vs King
     *   - King + Knight vs King
     *   - King + Bishop vs King + Bishop (same-color bishops)
     */
    static Boolean isInsufficientMaterial(String board) {
        // Categorize all pieces on the board
        Int whiteKnights = 0;
        Int whiteBishops = 0;
        Int blackKnights = 0;
        Int blackBishops = 0;
        Int otherWhite   = 0; // pawns, rooks, queens
        Int otherBlack   = 0;
        Int whiteBishopSquareColor = -1; // 0 = dark, 1 = light
        Int blackBishopSquareColor = -1;

        for (Int i : 0 ..< 64) {
            Char piece = board[i];
            if (piece == '.') {
                continue;
            }

            switch (piece) {
                case 'K', 'k': break; // ignore kings
                case 'N': whiteKnights++; break;
                case 'n': blackKnights++; break;
                case 'B': {
                    whiteBishops++;
                    whiteBishopSquareColor = (BoardUtils.getRank(i) + BoardUtils.getFile(i)) % 2;
                    break;
                }
                case 'b': {
                    blackBishops++;
                    blackBishopSquareColor = (BoardUtils.getRank(i) + BoardUtils.getFile(i)) % 2;
                    break;
                }
                default: {
                    if ('A' <= piece <= 'Z') {
                        otherWhite++;
                    } else {
                        otherBlack++;
                    }
                    break;
                }
            }
        }

        // If either side has a pawn, rook, or queen — sufficient material
        if (otherWhite > 0 || otherBlack > 0) {
            return False;
        }

        Int totalWhiteMinor = whiteKnights + whiteBishops;
        Int totalBlackMinor = blackKnights + blackBishops;

        // King vs King
        if (totalWhiteMinor == 0 && totalBlackMinor == 0) {
            return True;
        }

        // King + minor vs King
        if (totalWhiteMinor == 0 && totalBlackMinor == 1) {
            return True;
        }
        if (totalBlackMinor == 0 && totalWhiteMinor == 1) {
            return True;
        }

        // King + Bishop vs King + Bishop on same-color squares
        if (whiteBishops == 1 && blackBishops == 1
                && whiteKnights == 0 && blackKnights == 0
                && whiteBishopSquareColor == blackBishopSquareColor) {
            return True;
        }

        return False;
    }

    /**
     * Check for threefold repetition by comparing board positions.
     * A position is the board layout + active color + castling rights + en passant target.
     */
    static Boolean isThreefoldRepetition(MoveHistoryEntry[] moveHistory, String currentBoard,
                                          Color currentTurn, CastlingRights castlingRights,
                                          String? enPassantTarget) {
        // Build representation of the current position
        String currentPosition = buildPositionKey(currentBoard, currentTurn, castlingRights, enPassantTarget);

        Int count = 1; // Current position counts as one occurrence

        // Walk backwards through move history checking board-after states
        // We approximate position key from boardAfter + who moved (to derive turn)
        for (Int i : moveHistory.size >.. 0) {
            MoveHistoryEntry entry = moveHistory[i];

            // After this entry's move, the turn goes to the opposite color
            Color turnAfter = entry.color == Color.White ? Color.Black : Color.White;

            // Simplified position key using board + turn
            // Full key would need castling rights and en-passant at that point,
            // but boardAfter + turn is a reasonable approximation.
            if (entry.boardAfter == currentBoard && turnAfter == currentTurn) {
                count++;
                if (count >= 3) {
                    return True;
                }
            }
        }

        return False;
    }

    /**
     * Build a unique key representing a chess position for repetition comparison.
     */
    static String buildPositionKey(String board, Color turn, CastlingRights castlingRights,
                                    String? enPassantTarget) {
        String epStr = enPassantTarget ?: "-";
        return $"{board}|{turn}|{castlingRights}|{epStr}";
    }

    /**
     * Check the 50-move rule.
     * A draw can be claimed when 50 full moves (100 half-moves) have been made
     * without any pawn move or capture.
     */
    static Boolean isFiftyMoveRule(Int halfMoveClock) {
        return halfMoveClock >= 100;
    }
}
