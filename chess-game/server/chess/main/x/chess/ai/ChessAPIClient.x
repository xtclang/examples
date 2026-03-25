/**
 * Chess AI public entrypoint.
 *
 * Responsibilities are split into dedicated services:
 * - AIPositionEvaluator: board/position scoring
 * - AISearchEngine: minimax + alpha-beta
 * - AIOpeningBook: opening move suggestions
 * - AIMoveSelector: legal move collection + ordering
 * - AIUtility: randomness, fallback move, FEN conversion
 */
service ChessAPIClient {
    // Shared score constants for search decisions.
    static Int MIN_SCORE       = -1000000;
    static Int MAX_SCORE       =  1000000;
    static Int CHECKMATE_SCORE =  100000;

    static Int getPieceValue(Char piece) {
        return AIPositionEvaluator.getPieceValue(piece);
    }

    static Int getPSTValue(Char piece, Int square, Boolean isEndgame) {
        return AIPositionEvaluator.getPSTValue(piece, square, isEndgame);
    }

    static Boolean isEndgame(Char[] board) {
        return AIPositionEvaluator.isEndgame(board);
    }

    static Boolean isPassedPawn(Char[] board, Int square, Char pawn) {
        return AIPositionEvaluator.isPassedPawn(board, square, pawn);
    }

    static Int chebyshevDistance(Int sq1, Int sq2) {
        return AIPositionEvaluator.chebyshevDistance(sq1, sq2);
    }

    static Int evaluateBoard(Char[] board, GameRecord record) {
        return AIPositionEvaluator.evaluateBoard(board, record);
    }

    static Int minimax(Char[] board, GameRecord record, Int depth,
                       Int alpha, Int beta, Boolean isMaximizing) {
        return AISearchEngine.minimax(board, record, depth, alpha, beta, isMaximizing);
    }

    static Int scoreMoveHeuristic(Char piece, Int from, Int to, Char[] board, GameRecord record) {
        return AIMoveSelector.scoreMoveHeuristic(piece, from, to, board, record);
    }

    static Int hashRandom(Int seed, Int counter) {
        return AIUtility.hashRandom(seed, counter);
    }

    static (Int, Int) getOpeningMove(GameRecord record) {
        return AIOpeningBook.getOpeningMove(record);
    }

    /**
     * Main AI move selection entrypoint used by game logic.
     */
    (Int, Int, String?) findBestMove(GameRecord record) {
        Int moveCount = record.moveHistory.size;

        (Int openFrom, Int openTo) = AIOpeningBook.getOpeningMove(record);
        if (openFrom >= 0 && openTo >= 0) {
            if (AIUtility.hashRandom(moveCount, 1) % 100 < 70) {
                return (openFrom, openTo, Null);
            }
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Boolean endgame = AIPositionEvaluator.isEndgame(board);
        Int depth = endgame ? 3 : 2;

        (Int[] moveFroms, Int[] moveTos, Int[] moveScores) = AIMoveSelector.collectOrderedLegalMoves(record, board);
        if (moveFroms.empty) {
            return (-1, -1, Null);
        }

        Int bestScore = MIN_SCORE;
        Int bestFrom  = moveFroms[0];
        Int bestTo    = moveTos[0];
        String? bestPromotion = Null;
        Int alpha = MIN_SCORE;
        Int beta  = MAX_SCORE;

        for (Int i : 0 ..< moveFroms.size) {
            Int from = moveFroms[i];
            Int to   = moveTos[i];
            Char piece = board[from];

            Char[] newBoard = BoardUtils.cloneBoard(record.board);
            newBoard[to] = piece;
            newBoard[from] = '.';
            String? promo = Null;
            if (piece == 'p' && BoardUtils.getRank(to) == 7) {
                newBoard[to] = 'q';
                promo = "q";
            }

            Int score = AISearchEngine.minimax(newBoard, record, depth - 1, alpha, beta, False);

            Int variety = AIUtility.hashRandom(from * 64 + to, moveCount + i) % 5;
            score += variety;

            if (score > bestScore) {
                bestScore = score;
                bestFrom  = from;
                bestTo    = to;
                bestPromotion = promo;
            }
            if (score > alpha) {
                alpha = score;
            }
        }

        return (bestFrom, bestTo, bestPromotion);
    }

    /**
     * Returns a legal random fallback move when needed.
     */
    static (Int, Int, String?) findRandomLegalMove(GameRecord record) {
        return AIUtility.findRandomLegalMove(record);
    }

    /**
     * Exposes FEN conversion for external consumers.
     */
    static String boardToFen(GameRecord record) {
        return AIUtility.boardToFen(record);
    }
}
