/**
 * Legacy AI facade kept for compatibility.
 * Core logic lives in dedicated helper services.
 */
service ChessAI {
    // Legacy score constants retained for older call sites.
    static Int MIN_SCORE = -1000000;
    static Int MAX_SCORE = 1000000;
    static Int CHECKMATE_SCORE = 100000;

    static Int getPieceValue(Char piece) {
        return AIPositionEvaluator.getPieceValue(piece);
    }

    static Int getPieceSquareValue(Char piece, Int square, Boolean isBlack) {
        Boolean isEndgame = False;
        return AIPositionEvaluator.getPSTValue(piece, square, isEndgame);
    }

    static Boolean isEndgame(Char[] board) {
        return AIPositionEvaluator.isEndgame(board);
    }

    static Int totalMaterial(Char[] board) {
        Int total = 0;
        for (Int i : 0 ..< 64) {
            Char piece = board[i];
            if (piece != '.' && piece != 'K' && piece != 'k') {
                total += AIPositionEvaluator.getPieceValue(piece);
            }
        }
        return total;
    }

    static Int evaluateBoard(Char[] board, GameRecord record) {
        return AIPositionEvaluator.evaluateBoard(board, record);
    }
    /**
     * Counts pseudo-legal mobility for a side.
     */

    static Int chebyshevDistance(Int sq1, Int sq2) {
        return AIPositionEvaluator.chebyshevDistance(sq1, sq2);
    }

    static Boolean isPassedPawn(Char[] board, Int square, Char pawn) {
        return AIPositionEvaluator.isPassedPawn(board, square, pawn);
    }

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

    /**
     * Scores one move using heuristic + shallow evaluation blend.
     */
    static Int scoreMove(Char piece, Int from, Int to, Char[] board, GameRecord record) {
        Int score = AIMoveSelector.scoreMoveHeuristic(piece, from, to, board, record);

        Char[] testBoard = BoardUtils.cloneBoard(board);
        testBoard[to] = piece;
        testBoard[from] = '.';
        if (piece == 'p' && BoardUtils.getRank(to) == 7) {
            testBoard[to] = 'q';
            score += AIPositionEvaluator.QUEEN_VALUE - AIPositionEvaluator.PAWN_VALUE;
        }

        score += AIPositionEvaluator.evaluateBoard(testBoard, record) / 10;
        return score;
    }

    static Int hashRandom(Int seed, Int counter) {
        return AIUtility.hashRandom(seed, counter);
    }

    static Int randomInt(Int max, Int moveCount, Int counter) {
        if (max <= 0) {
            return 0;
        }
        Int rand = AIUtility.hashRandom(moveCount * 1009 + counter * 7919, counter);
        return rand % max;
    }

    static Boolean isOpeningPhase(GameRecord record) {
        return record.moveHistory.size < 12;
    }

    static (Int, Int) getOpeningMove(GameRecord record) {
        return AIOpeningBook.getOpeningMove(record);
    }

    /**
     * Queries the modern API client and returns move with evaluation score.
     */
    static (Int, Int, Int) findBestMove(GameRecord record) {
        ChessAPIClient client = new ChessAPIClient();
        (Int from, Int to, String? promotion) = client.findBestMove(record);
        if (from < 0 || to < 0) {
            return (-1, -1, MIN_SCORE);
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Char piece = board[from];
        board[to] = piece;
        board[from] = '.';
        if (promotion != Null && promotion == "q") {
            board[to] = 'q';
        }

        Int score = AIPositionEvaluator.evaluateBoard(board, record);
        return (from, to, score);
    }

    /**
     * Legacy minimax wrapper that picks best move from ordered candidates.
     */
    static (Int, Int, Int) findBestMoveWithMinimax(GameRecord record, Char[] board, Int depth) {
        (Int[] froms, Int[] tos, Int[] scores) = AIMoveSelector.collectOrderedLegalMoves(record, board);
        if (froms.empty) {
            return (-1, -1, MIN_SCORE);
        }

        Int bestScore = MIN_SCORE;
        Int bestFrom = froms[0];
        Int bestTo = tos[0];
        Int alpha = MIN_SCORE;
        Int beta = MAX_SCORE;

        for (Int i : 0 ..< froms.size) {
            Int from = froms[i];
            Int to = tos[i];
            Char piece = board[from];

            Char[] newBoard = BoardUtils.cloneBoard(board);
            newBoard[to] = piece;
            newBoard[from] = '.';
            if (piece == 'p' && BoardUtils.getRank(to) == 7) {
                newBoard[to] = 'q';
            }

            Int score = AISearchEngine.minimax(newBoard, record, depth - 1, alpha, beta, False);
            if (score > bestScore) {
                bestScore = score;
                bestFrom = from;
                bestTo = to;
            }
            if (score > alpha) {
                alpha = score;
            }
        }

        return (bestFrom, bestTo, bestScore);
    }

    static Int minimax(Char[] board, GameRecord record, Int depth, Int alpha, Int beta, Boolean isMaximizing) {
        return AISearchEngine.minimax(board, record, depth, alpha, beta, isMaximizing);
    }

    /**
     * Heuristic-only move picker with bounded randomness among top choices.
     */
    static (Int, Int, Int) findBestMoveHeuristic(GameRecord record, Char[] board) {
        (Int[] allFroms, Int[] allTos, Int[] allScores) = AIMoveSelector.collectOrderedLegalMoves(record, board);
        if (allFroms.empty) {
            return (-1, -1, MIN_SCORE);
        }

        Int bestScore = allScores[0];
        for (Int i : 1 ..< allScores.size) {
            if (allScores[i] > bestScore) {
                bestScore = allScores[i];
            }
        }

        Int threshold = (bestScore.abs() * 15) / 100;
        if (threshold < 50) {
            threshold = 50;
        }
        Int minAcceptableScore = bestScore - threshold;

        Int[] topFroms = new Int[];
        Int[] topTos = new Int[];
        Int[] topScores = new Int[];

        for (Int i : 0 ..< allFroms.size) {
            if (allScores[i] >= minAcceptableScore) {
                topFroms = topFroms + allFroms[i];
                topTos = topTos + allTos[i];
                topScores = topScores + allScores[i];
            }
        }

        if (topFroms.size > 5) {
            topFroms = topFroms[0 ..< 5];
            topTos = topTos[0 ..< 5];
            topScores = topScores[0 ..< 5];
        }

        Int index = randomInt(topFroms.size, record.moveHistory.size, topFroms.size + allFroms.size);
        return (topFroms[index], topTos[index], topScores[index]);
    }
}
