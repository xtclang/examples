/**
 * Move ordering and heuristic scoring for search.
 */
service AIMoveSelector {
    // Heuristic tuning constants used to prioritize move ordering.
    static Int CASTLING_BONUS    = 60;
    static Int DEVELOPMENT_BONUS = 30;
    static Int CENTER_BONUS      = 25;
    static Int CHECK_BONUS       = 50;

    /**
     * Scores one candidate move for ordering before deeper search.
     */
    static Int scoreMoveHeuristic(Char piece, Int from, Int to, Char[] board, GameRecord record) {
        Int score = 0;
        Char target = board[to];

        if (target != '.') {
            score += AIPositionEvaluator.getPieceValue(target) * 10 - AIPositionEvaluator.getPieceValue(piece);
        }

        if (piece == 'p' && BoardUtils.getRank(to) == 7) {
            score += AIPositionEvaluator.QUEEN_VALUE - AIPositionEvaluator.PAWN_VALUE;
        }

        if (piece == 'p') {
            Int file = BoardUtils.getFile(to);
            Int rank = BoardUtils.getRank(to);
            if ((file == 3 || file == 4) && rank >= 3 && rank <= 5) {
                score += CENTER_BONUS;
            }
        }

        if (record.moveHistory.size < 20 && (piece == 'n' || piece == 'b') && BoardUtils.getRank(from) == 0) {
            score += DEVELOPMENT_BONUS;
        }

        if (piece == 'k') {
            Int fileDiff = (BoardUtils.getFile(to) - BoardUtils.getFile(from)).abs();
            if (fileDiff == 2) {
                score += CASTLING_BONUS;
            }
        }

        Char[] testBoard = BoardUtils.cloneBoard(board);
        testBoard[to] = piece;
        testBoard[from] = '.';
        if (CheckDetection.isInCheck(testBoard.freeze(), Color.White)) {
            score += CHECK_BONUS;
        }

        return score;
    }

    /**
     * Collects all legal Black moves and sorts them by heuristic score (descending).
     */
    static (Int[], Int[], Int[]) collectOrderedLegalMoves(GameRecord record, Char[] board) {
        Int[] moveFroms  = new Int[];
        Int[] moveTos    = new Int[];
        Int[] moveScores = new Int[];

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
                if (!PieceValidator.isLegal(piece, from, to, board,
                        record.castlingRights, record.enPassantTarget)) {
                    continue;
                }

                Char[] testBoard = BoardUtils.cloneBoard(record.board);
                testBoard[to] = piece;
                testBoard[from] = '.';
                if (CheckDetection.isInCheck(testBoard.freeze(), Color.Black)) {
                    continue;
                }

                Int hScore = scoreMoveHeuristic(piece, from, to, board, record);
                moveFroms  = moveFroms  + from;
                moveTos    = moveTos    + to;
                moveScores = moveScores + hScore;
            }
        }

        for (Int i : 0 ..< moveFroms.size) {
            Int maxIdx = i;
            for (Int j : i + 1 ..< moveFroms.size) {
                if (moveScores[j] > moveScores[maxIdx]) {
                    maxIdx = j;
                }
            }
            if (maxIdx != i) {
                Int tmpF = moveFroms[i];
                Int tmpT = moveTos[i];
                Int tmpS = moveScores[i];
                moveFroms  = moveFroms.replace(i, moveFroms[maxIdx]);
                moveFroms  = moveFroms.replace(maxIdx, tmpF);
                moveTos    = moveTos.replace(i, moveTos[maxIdx]);
                moveTos    = moveTos.replace(maxIdx, tmpT);
                moveScores = moveScores.replace(i, moveScores[maxIdx]);
                moveScores = moveScores.replace(maxIdx, tmpS);
            }
        }

        return (moveFroms, moveTos, moveScores);
    }
}
