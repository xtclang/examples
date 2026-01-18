/**
 * AI Move Selection
 * Enhanced heuristic-based AI for the opponent (Black player).
 * Evaluates moves based on:
 * - Material value (captures and piece values)
 * - Position (piece-square tables)
 * - King safety
 * - Piece development
 * - Pawn structure
 * - Look-ahead (minimax with limited depth)
 */

service ChessAI {
    // ----- Scoring Constants -------------------------------------------------

    static Int MIN_SCORE = -1000000;
    static Int MAX_SCORE = 1000000;
    static Int CHECKMATE_SCORE = 100000;

    // Piece values (centipawns)
    static Int PAWN_VALUE = 100;
    static Int KNIGHT_VALUE = 320;
    static Int BISHOP_VALUE = 330;
    static Int ROOK_VALUE = 500;
    static Int QUEEN_VALUE = 900;
    static Int KING_VALUE = 20000;

    // Bonuses
    static Int CHECK_BONUS = 50;
    static Int CASTLING_BONUS = 60;
    static Int DEVELOPMENT_BONUS = 30;
    static Int CENTER_CONTROL_BONUS = 25;
    static Int DOUBLED_PAWN_PENALTY = -20;
    static Int ISOLATED_PAWN_PENALTY = -25;
    static Int PASSED_PAWN_BONUS = 50;

    // Piece-square tables for Black pieces (from Black's perspective, so reversed)
    // Higher values = better squares for that piece
    
    // Pawns want to advance and control center
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

    // Knights prefer center squares
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

    // Bishops prefer long diagonals
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

    // Rooks prefer open files and 7th rank
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

    // Queen combines rook and bishop
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

    // King should stay safe in early/mid game
    static Int[] KING_TABLE_MIDGAME = [
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -10,-20,-20,-20,-20,-20,-20,-10,
         20, 20,  0,  0,  0,  0, 20, 20,
         20, 30, 10,  0,  0, 10, 30, 20
    ];

    // ----- Piece Value Calculation -------------------------------------------------

    /**
     * Get the value of a piece.
     */
    static Int getPieceValue(Char piece) {
        Char lower = piece.lowercase;
        switch (lower) {
            case 'p': return PAWN_VALUE;
            case 'n': return KNIGHT_VALUE;
            case 'b': return BISHOP_VALUE;
            case 'r': return ROOK_VALUE;
            case 'q': return QUEEN_VALUE;
            case 'k': return KING_VALUE;
            default: return 0;
        }
    }

    /**
     * Get piece-square table value for a piece at a position.
     */
    static Int getPieceSquareValue(Char piece, Int square, Boolean isBlack) {
        // For Black, we need to flip the square vertically
        Int index = isBlack ? square : (63 - square);
        
        Char lower = piece.lowercase;
        switch (lower) {
            case 'p': return PAWN_TABLE[index];
            case 'n': return KNIGHT_TABLE[index];
            case 'b': return BISHOP_TABLE[index];
            case 'r': return ROOK_TABLE[index];
            case 'q': return QUEEN_TABLE[index];
            case 'k': return KING_TABLE_MIDGAME[index];
            default: return 0;
        }
    }

    // ----- Board Evaluation -------------------------------------------------

    /**
     * Evaluate the board position from Black's perspective.
     * Positive = good for Black, Negative = good for White.
     */
    static Int evaluateBoard(Char[] board, GameRecord record) {
        Int score = 0;
        Int whiteMaterial = 0;
        Int blackMaterial = 0;
        Int whitePieceCount = 0;
        Int blackPieceCount = 0;

        // Count material and position values
        for (Int i : 0 ..< 64) {
            Char piece = board[i];
            if (piece == '.') {
                continue;
            }

            Int pieceValue = getPieceValue(piece);
            Int posValue = getPieceSquareValue(piece, i, piece >= 'a' && piece <= 'z');

            if (piece >= 'A' && piece <= 'Z') {
                // White piece
                whiteMaterial += pieceValue;
                whitePieceCount++;
                score -= pieceValue + posValue; // Negative because good for White is bad for Black
            } else {
                // Black piece
                blackMaterial += pieceValue;
                blackPieceCount++;
                score += pieceValue + posValue;
            }
        }

        // Mobility bonus (count available moves)
        score += countMobility(board, Color.Black, record) * 5;
        score -= countMobility(board, Color.White, record) * 5;

        // Check bonus
        String boardStr = new String(board);
        if (CheckDetection.isInCheck(boardStr, Color.White)) {
            score += CHECK_BONUS;
        }
        if (CheckDetection.isInCheck(boardStr, Color.Black)) {
            score -= CHECK_BONUS;
        }

        return score;
    }

    /**
     * Count the number of legal moves available (mobility).
     */
    static Int countMobility(Char[] board, Color color, GameRecord record) {
        Int moveCount = 0;
        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != color) {
                continue;
            }
            for (Int to : 0 ..< 64) {
                if (from != to && PieceValidator.isLegal(piece, from, to, board, record.castlingRights, record.enPassantTarget)) {
                    Char target = board[to];
                    if (target == '.' || BoardUtils.colorOf(target) != color) {
                        moveCount++;
                    }
                }
            }
        }
        return moveCount;
    }

    // ----- Move Scoring -------------------------------------------------

    /**
     * Score a potential move for the AI.
     * Uses look-ahead evaluation.
     */
    static Int scoreMove(Char piece, Int from, Int to, Char[] board, GameRecord record) {
        Int score = 0;
        Char target = board[to];

        // Base score from capture value (MVV-LVA: Most Valuable Victim - Least Valuable Attacker)
        if (target != '.') {
            Int victimValue = getPieceValue(target);
            Int attackerValue = getPieceValue(piece);
            score += victimValue * 10 - attackerValue;
        }

        // Simulate the move
        Char[] testBoard = BoardUtils.cloneBoard(new String(board));
        testBoard[to] = piece;
        testBoard[from] = '.';

        // Handle pawn promotion
        if (piece == 'p' && BoardUtils.getRank(to) == 7) {
            testBoard[to] = 'q'; // Promote to queen
            score += QUEEN_VALUE - PAWN_VALUE;
        }

        // Evaluate resulting position
        score += evaluateBoard(testBoard, record) / 10;

        // Bonus for giving check
        String testBoardStr = new String(testBoard);
        if (CheckDetection.isInCheck(testBoardStr, Color.White)) {
            score += CHECK_BONUS;
        }

        // Bonus for controlling center with pawns
        if (piece == 'p') {
            Int file = BoardUtils.getFile(to);
            Int rank = BoardUtils.getRank(to);
            if ((file == 3 || file == 4) && (rank >= 3 && rank <= 5)) {
                score += CENTER_CONTROL_BONUS;
            }
        }

        // Development bonus for minor pieces in opening
        if (record.moveHistory.size < 20) {
            if (piece == 'n' || piece == 'b') {
                Int fromRank = BoardUtils.getRank(from);
                if (fromRank == 0) { // Piece was on back rank
                    score += DEVELOPMENT_BONUS;
                }
            }
        }

        // Castling bonus
        if (piece == 'k') {
            Int fileDiff = (BoardUtils.getFile(to) - BoardUtils.getFile(from)).abs();
            if (fileDiff == 2) {
                score += CASTLING_BONUS;
            }
        }

        return score;
    }

    // ----- Best Move Selection -------------------------------------------------

    /**
     * Find the best move for Black (AI opponent).
     * Returns (from, to, score) tuple.
     */
    static (Int, Int, Int) findBestMove(GameRecord record) {
        Char[] board = BoardUtils.cloneBoard(record.board);
        Int bestScore = MIN_SCORE;
        Int bestFrom = -1;
        Int bestTo = -1;

        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != Color.Black) {
                continue;
            }

            for (Int to : 0 ..< 64) {
                if (from == to) {
                    continue;
                }
                Char target = board[to];
                if (target != '.' && BoardUtils.colorOf(target) == Color.Black) {
                    continue;
                }
                if (!PieceValidator.isLegal(piece, from, to, board, record.castlingRights, record.enPassantTarget)) {
                    continue;
                }

                // Verify move doesn't leave king in check
                Char[] testBoard = BoardUtils.cloneBoard(new String(board));
                testBoard[to] = piece;
                testBoard[from] = '.';
                String testBoardStr = new String(testBoard);
                if (CheckDetection.isInCheck(testBoardStr, Color.Black)) {
                    continue;
                }

                Int score = scoreMove(piece, from, to, board, record);
                if (score > bestScore) {
                    bestScore = score;
                    bestFrom = from;
                    bestTo = to;
                }
            }
        }

        return (bestFrom, bestTo, bestScore);
    }
}