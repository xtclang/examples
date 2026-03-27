/**
 * Minimax search with alpha-beta pruning.
 */
service AISearchEngine {
    // Search score bounds and terminal score.
    static Int MIN_SCORE       = -1000000;
    static Int MAX_SCORE       =  1000000;
    static Int CHECKMATE_SCORE =  100000;

    /**
     * Runs depth-limited minimax with alpha-beta pruning.
     */
    static Int minimax(Char[] board, GameRecord record, Int depth,
                       Int alpha, Int beta, Boolean isMaximizing) {
        if (depth <= 0) {
            return AIPositionEvaluator.evaluateBoard(board, record);
        }

        Color turn = isMaximizing ? Black : White;
        Boolean inCheck = CheckDetection.isInCheck(board.freeze(), turn);
        Boolean hasLegalMove = False;

        if (isMaximizing) {
            Int maxEval = MIN_SCORE;
            for (Int from : 0 ..< 64) {
                Char piece = board[from];
                if (piece == '.' || BoardUtils.colorOf(piece) != turn) {
                    continue;
                }
                for (Int to : 0 ..< 64) {
                    if (from == to) {
                        continue;
                    }
                    Char target = board[to];
                    if (target != '.' && BoardUtils.colorOf(target) == turn) {
                        continue;
                    }
                    if (!PieceValidator.isLegal(piece, from, to, board,
                            record.castlingRights, record.enPassantTarget)) {
                        continue;
                    }

                    Char[] newBoard = BoardUtils.cloneBoard(board);
                    newBoard[to] = piece;
                    newBoard[from] = '.';
                    if (piece == 'p' && BoardUtils.getRank(to) == 7) {
                        newBoard[to] = 'q';
                    }
                    if (CheckDetection.isInCheck(newBoard.freeze(), turn)) {
                        continue;
                    }

                    hasLegalMove = True;
                    Int eval = minimax(newBoard, record, depth - 1, alpha, beta, False);
                    if (eval > maxEval) {
                        maxEval = eval;
                    }
                    if (eval > alpha) {
                        alpha = eval;
                    }
                    if (beta <= alpha) {
                        return maxEval;
                    }
                }
            }
            if (!hasLegalMove) {
                return inCheck ? -CHECKMATE_SCORE : 0;
            }
            return maxEval;
        }

        Int minEval = MAX_SCORE;
        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != turn) {
                continue;
            }
            for (Int to : 0 ..< 64) {
                if (from == to) {
                    continue;
                }
                Char target = board[to];
                if (target != '.' && BoardUtils.colorOf(target) == turn) {
                    continue;
                }
                if (!PieceValidator.isLegal(piece, from, to, board,
                        record.castlingRights, record.enPassantTarget)) {
                    continue;
                }

                Char[] newBoard = BoardUtils.cloneBoard(board);
                newBoard[to] = piece;
                newBoard[from] = '.';
                if (piece == 'P' && BoardUtils.getRank(to) == 0) {
                    newBoard[to] = 'Q';
                }
                if (CheckDetection.isInCheck(newBoard.freeze(), turn)) {
                    continue;
                }

                hasLegalMove = True;
                Int eval = minimax(newBoard, record, depth - 1, alpha, beta, True);
                if (eval < minEval) {
                    minEval = eval;
                }
                if (eval < beta) {
                    beta = eval;
                }
                if (beta <= alpha) {
                    return minEval;
                }
            }
        }

        if (!hasLegalMove) {
            return inCheck ? CHECKMATE_SCORE : 0;
        }
        return minEval;
    }
}
