/**
 * Position evaluation helpers for chess AI.
 * Pure functions: no external mutable state.
 */
service AIPositionEvaluator {
    // Evaluation bonuses and penalties.
    static Int CHECK_BONUS    = 50;
    static Int ROOK_7TH_BONUS = 20;
    static Int KING_PROXIMITY = 10;

    // Material values.
    static Int PAWN_VALUE   = 100;
    static Int KNIGHT_VALUE = 320;
    static Int BISHOP_VALUE = 330;
    static Int ROOK_VALUE   = 500;
    static Int QUEEN_VALUE  = 900;
    static Int KING_VALUE   = 20000;

    static Int[] PAWN_TABLE = [
         0,  0,  0,  0,  0,  0,  0,  0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
         5,  5, 10, 25, 25, 10,  5,  5,
         0,  0,  0, 20, 20,  0,  0,  0,
         5, -5,-10,  0,  0,-10, -5,  5,
         5, 10, 10,-20,-20, 10, 10,  5,
         0,  0,  0,  0,  0,  0,  0,  0
    ];

    static Int[] KNIGHT_TABLE = [
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -30,  0, 10, 15, 15, 10,  0,-30,
        -30,  5, 15, 20, 20, 15,  5,-30,
        -30,  0, 15, 20, 20, 15,  0,-30,
        -30,  5, 10, 15, 15, 10,  5,-30,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50
    ];

    static Int[] BISHOP_TABLE = [
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5, 10, 10,  5,  0,-10,
        -10,  5,  5, 10, 10,  5,  5,-10,
        -10,  0, 10, 10, 10, 10,  0,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -20,-10,-10,-10,-10,-10,-10,-20
    ];

    static Int[] ROOK_TABLE = [
         0,  0,  0,  0,  0,  0,  0,  0,
         5, 10, 10, 10, 10, 10, 10,  5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
         0,  0,  0,  5,  5,  0,  0,  0
    ];

    static Int[] QUEEN_TABLE = [
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5,  5,  5,  5,  0,-10,
         -5,  0,  5,  5,  5,  5,  0, -5,
          0,  0,  5,  5,  5,  5,  0, -5,
        -10,  5,  5,  5,  5,  5,  0,-10,
        -10,  0,  5,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20
    ];

    static Int[] KING_TABLE_MID = [
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -10,-20,-20,-20,-20,-20,-20,-10,
         20, 20,  0,  0,  0,  0, 20, 20,
         20, 30, 10,  0,  0, 10, 30, 20
    ];

    static Int[] KING_TABLE_END = [
        -50,-40,-30,-20,-20,-30,-40,-50,
        -30,-20,-10,  0,  0,-10,-20,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-30,  0,  0,  0,  0,-30,-30,
        -50,-30,-30,-30,-30,-30,-30,-50
    ];

    static Int[] PASSED_PAWN_BONUS = [0, 120, 80, 50, 30, 15, 10, 0];

    /**
     * Returns the material value for a piece symbol.
     */
    static Int getPieceValue(Char piece) {
        switch (piece.lowercase) {
            case 'p': return PAWN_VALUE;
            case 'n': return KNIGHT_VALUE;
            case 'b': return BISHOP_VALUE;
            case 'r': return ROOK_VALUE;
            case 'q': return QUEEN_VALUE;
            case 'k': return KING_VALUE;
            default:  return 0;
        }
    }

    /**
     * Returns piece-square table value, mirrored for Black pieces.
     */
    static Int getPSTValue(Char piece, Int square, Boolean isEndgame) {
        Boolean isWhite = 'A' <= piece <= 'Z';
        Int index = isWhite ? square : (63 - square);

        switch (piece.lowercase) {
            case 'p':  return PAWN_TABLE[index];
            case 'n':  return KNIGHT_TABLE[index];
            case 'b':  return BISHOP_TABLE[index];
            case 'r':  return ROOK_TABLE[index];
            case 'q':  return QUEEN_TABLE[index];
            case 'k':  return isEndgame ? KING_TABLE_END[index] : KING_TABLE_MID[index];
            default:   return 0;
        }
    }

    /**
     * Detects simplified positions where endgame king tables are preferred.
     */
    static Boolean isEndgame(Char[] board) {
        Int whiteQueens = 0;
        Int blackQueens = 0;
        Int whiteMinor  = 0;
        Int blackMinor  = 0;

        for (Int i : 0 ..< 64) {
            switch (board[i]) {
                case 'Q': whiteQueens++; break;
                case 'q': blackQueens++; break;
                case 'R': whiteMinor++;  break;
                case 'r': blackMinor++;  break;
                case 'B': whiteMinor++;  break;
                case 'b': blackMinor++;  break;
                case 'N': whiteMinor++;  break;
                case 'n': blackMinor++;  break;
                default: break;
            }
        }

        if (whiteQueens == 0 && blackQueens == 0) {
            return True;
        }
        return whiteQueens <= 1 && whiteMinor <= 1
            && blackQueens <= 1 && blackMinor <= 1;
    }

    /**
     * Checks whether a pawn has no opposing pawns ahead on adjacent files.
     */
    static Boolean isPassedPawn(Char[] board, Int square, Char pawn) {
        Int file = BoardUtils.getFile(square);
        Int rank = BoardUtils.getRank(square);
        Int minFile = file > 0 ? file - 1 : 0;
        Int maxFile = file < 7 ? file + 1 : 7;

        if (pawn == 'p') {
            for (Int r : rank + 1 ..< 8) {
                for (Int f : minFile ..< maxFile + 1) {
                    if (board[r * 8 + f] == 'P') {
                        return False;
                    }
                }
            }
        } else {
            for (Int r : 0 ..< rank) {
                for (Int f : minFile ..< maxFile + 1) {
                    if (board[r * 8 + f] == 'p') {
                        return False;
                    }
                }
            }
        }
        return True;
    }

    /**
     * Computes king distance for endgame opposition/proximity scoring.
     */
    static Int chebyshevDistance(Int sq1, Int sq2) {
        Int rankDiff = (BoardUtils.getRank(sq1) - BoardUtils.getRank(sq2)).abs();
        Int fileDiff = (BoardUtils.getFile(sq1) - BoardUtils.getFile(sq2)).abs();
        return rankDiff.maxOf(fileDiff);
    }

    /**
     * Produces a signed score from Black's perspective (higher is better for Black).
     */
    static Int evaluateBoard(Char[] board, GameRecord record) {
        Int score = 0;
        Boolean endgame = isEndgame(board);
        Int whiteKingPos = -1;
        Int blackKingPos = -1;

        for (Int i : 0 ..< 64) {
            Char piece = board[i];
            if (piece == '.') {
                continue;
            }

            if (piece == 'K') { whiteKingPos = i; }
            if (piece == 'k') { blackKingPos = i; }

            Int matValue = getPieceValue(piece);
            Int posValue = getPSTValue(piece, i, endgame);

            if ('A' <= piece <= 'Z') {
                score -= matValue + posValue;
            } else {
                score += matValue + posValue;
            }

            if (piece == 'r' && BoardUtils.getRank(i) == 6) {
                score += ROOK_7TH_BONUS;
            } else if (piece == 'R' && BoardUtils.getRank(i) == 1) {
                score -= ROOK_7TH_BONUS;
            }

            if (endgame && (piece == 'p' || piece == 'P')) {
                if (isPassedPawn(board, i, piece)) {
                    Int rank = BoardUtils.getRank(i);
                    if (piece == 'p') {
                        score += PASSED_PAWN_BONUS[rank];
                    } else {
                        score -= PASSED_PAWN_BONUS[7 - rank];
                    }
                }
            }
        }

        immutable Char[] immutableBoard = board.freeze();
        if (CheckDetection.isInCheck(immutableBoard, Color.White)) {
            score += CHECK_BONUS;
        }
        if (CheckDetection.isInCheck(immutableBoard, Color.Black)) {
            score -= CHECK_BONUS;
        }

        if (endgame && whiteKingPos >= 0 && blackKingPos >= 0) {
            score -= chebyshevDistance(whiteKingPos, blackKingPos) * KING_PROXIMITY;
        }

        return score;
    }
}
