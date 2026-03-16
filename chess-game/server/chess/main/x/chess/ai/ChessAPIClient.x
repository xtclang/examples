/**
 * Chess AI Engine
 *
 * Evaluation-based AI for the opponent (Black player).
 * Uses minimax search with alpha-beta pruning and position evaluation:
 * - Material counting with standard piece values
 * - Piece-square tables for positional play
 * - Endgame awareness (deeper search, king centralization)
 * - Check and king safety bonuses
 * - Passed pawn evaluation
 * - Rook on 7th rank bonus
 * - Opening development encouragement
 * - Move ordering via MVV-LVA heuristic
 *
 * Search depth: 2-ply midgame, 3-ply endgame.
 */
service ChessAPIClient {

    // ----- Scoring Constants -------------------------------------------------

    static Int MIN_SCORE       = -1000000;
    static Int MAX_SCORE       =  1000000;
    static Int CHECKMATE_SCORE =  100000;

    // ----- Piece Values (centipawns) -----------------------------------------

    static Int PAWN_VALUE   = 100;
    static Int KNIGHT_VALUE = 320;
    static Int BISHOP_VALUE = 330;
    static Int ROOK_VALUE   = 500;
    static Int QUEEN_VALUE  = 900;
    static Int KING_VALUE   = 20000;

    // ----- Positional Bonuses ------------------------------------------------

    static Int CHECK_BONUS       = 50;
    static Int CASTLING_BONUS    = 60;
    static Int DEVELOPMENT_BONUS = 30;
    static Int CENTER_BONUS      = 25;
    static Int MOBILITY_BONUS    = 5;
    static Int ROOK_7TH_BONUS    = 20;
    static Int KING_PROXIMITY    = 10;

    // ----- Piece-Square Tables (from White's perspective) --------------------
    // For White pieces: index = square.  For Black pieces: index = 63 - square.

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

    // Passed pawn bonus by rank (from Black's perspective: rank 0 = 8th)
    static Int[] PASSED_PAWN_BONUS = [0, 120, 80, 50, 30, 15, 10, 0];

    // ----- Piece Value Lookup ------------------------------------------------

    /**
     * Get material value for a piece character.
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

    // ----- Piece-Square Table Lookup -----------------------------------------

    /**
     * Get positional value from piece-square tables.
     * White pieces use the table index directly; Black pieces mirror (63 - square).
     */
    static Int getPSTValue(Char piece, Int square, Boolean isEndgame) {
        Boolean isWhite = 'A' <= piece <= 'Z';
        Int index = isWhite ? square : (63 - square);

        return switch (piece.lowercase) {
                case 'p': PAWN_TABLE[index];
                case 'n': KNIGHT_TABLE[index];
                case 'b': BISHOP_TABLE[index];
                case 'r': ROOK_TABLE[index];
                case 'q': QUEEN_TABLE[index];
                case 'k': isEndgame ? KING_TABLE_END[index] : KING_TABLE_MID[index];
                default:  0;
        };
    }

    // ----- Endgame Detection -------------------------------------------------

    /**
     * Determine if position is in endgame phase.
     * Endgame = no queens, or every side with a queen has at most one minor/major piece.
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

    // ----- Passed Pawn Detection ---------------------------------------------

    /**
     * Check if a pawn is a passed pawn (no opposing pawns blocking or adjacent).
     */
    static Boolean isPassedPawn(Char[] board, Int square, Char pawn) {
        Int file = BoardUtils.getFile(square);
        Int rank = BoardUtils.getRank(square);
        Int minFile = file > 0 ? file - 1 : 0;
        Int maxFile = file < 7 ? file + 1 : 7;

        if (pawn == 'p') {
            // Black pawn advances toward rank 7
            for (Int r : rank + 1 ..< 8) {
                for (Int f : minFile ..< maxFile + 1) {
                    if (board[r * 8 + f] == 'P') {
                        return False;
                    }
                }
            }
        } else {
            // White pawn advances toward rank 0
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

    // ----- Chebyshev Distance ------------------------------------------------

    /**
     * Max of rank distance and file distance between two squares.
     */
    static Int chebyshevDistance(Int sq1, Int sq2) {
        Int rankDiff = (BoardUtils.getRank(sq1) - BoardUtils.getRank(sq2)).abs();
        Int fileDiff = (BoardUtils.getFile(sq1) - BoardUtils.getFile(sq2)).abs();
        return rankDiff.maxOf(fileDiff);
    }

    // ----- Board Evaluation --------------------------------------------------

    /**
     * Evaluate the board from Black's perspective.
     * Positive = good for Black, Negative = good for White.
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

            // Rook on 7th rank bonus
            if (piece == 'r' && BoardUtils.getRank(i) == 6) {
                score += ROOK_7TH_BONUS;
            } else if (piece == 'R' && BoardUtils.getRank(i) == 1) {
                score -= ROOK_7TH_BONUS;
            }

            // Passed pawn bonus in endgame
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

        // Check bonus
        immutable Char[] immutableBoard = board.freeze();
        if (CheckDetection.isInCheck(immutableBoard, White)) {
            score += CHECK_BONUS;
        }
        if (CheckDetection.isInCheck(immutableBoard, Black)) {
            score -= CHECK_BONUS;
        }

        // King proximity in endgame (drive opponent king to edge for mating)
        if (endgame && whiteKingPos >= 0 && blackKingPos >= 0) {
            score -= chebyshevDistance(whiteKingPos, blackKingPos) * KING_PROXIMITY;
        }

        return score;
    }

    // ----- Minimax with Alpha-Beta Pruning -----------------------------------

    /**
     * Minimax tree search with alpha-beta pruning.
     * @param isMaximizing True = Black's turn (maximize), False = White's turn (minimize)
     */
    static Int minimax(Char[] board, GameRecord record, Int depth,
                       Int alpha, Int beta, Boolean isMaximizing) {
        if (depth <= 0) {
            return evaluateBoard(board, record);
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
                return hasLegalMove
                ? maxEval
                : inCheck ? -CHECKMATE_SCORE : 0;
            }
            return maxEval;
        } else {
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
                return hasLegalMove
                ? minEval
                : inCheck ? -CHECKMATE_SCORE : 0;
            }
            return minEval;
        }
    }

    // ----- Single-Ply Move Scoring -------------------------------------------

    /**
     * Quick heuristic score for a single move (used for move ordering).
     * MVV-LVA: Most Valuable Victim - Least Valuable Attacker.
     */
    static Int scoreMoveHeuristic(Char piece, Int from, Int to, Char[] board, GameRecord record) {
        Int score = 0;
        Char target = board[to];

        // Capture bonus (MVV-LVA)
        if (target != '.') {
            score += getPieceValue(target) * 10 - getPieceValue(piece);
        }

        // Promotion bonus
        if (piece == 'p' && BoardUtils.getRank(to) == 7) {
            score += QUEEN_VALUE - PAWN_VALUE;
        }

        // Center control for pawns
        if (piece == 'p') {
            Int file = BoardUtils.getFile(to);
            Int rank = BoardUtils.getRank(to);
            if ((file == 3 || file == 4) && rank >= 3 && rank <= 5) {
                score += CENTER_BONUS;
            }
        }

        // Development bonus for minor pieces in opening
        if (record.moveHistory.size < 20 && (piece == 'n' || piece == 'b') && BoardUtils.getRank(from) == 0) {
            score += DEVELOPMENT_BONUS;
        }

        // Castling bonus
        if (piece == 'k') {
            Int fileDiff = (BoardUtils.getFile(to) - BoardUtils.getFile(from)).abs();
            if (fileDiff == 2) {
                score += CASTLING_BONUS;
            }
        }

        // Check bonus
        Char[] testBoard = BoardUtils.cloneBoard(board);
        testBoard[to] = piece;
        testBoard[from] = '.';
        if (CheckDetection.isInCheck(testBoard.freeze(), White)) {
            score += CHECK_BONUS;
        }

        return score;
    }

    // ----- Pseudo-Random for Variety -----------------------------------------

    /**
     * Deterministic hash-based pseudo-random for move variety.
     */
    static Int hashRandom(Int seed, Int counter) {
        Int hash = seed ^ (counter * 2654435761);
        hash = ((hash >> 16) ^ hash) * 73244475;
        hash = ((hash >> 16) ^ hash) * 73244475;
        hash = (hash >> 16) ^ hash;
        return hash.abs();
    }

    // ----- Opening Book (small) ----------------------------------------------

    static String[][] OPENING_RESPONSES = [
        // After 1.e4: Sicilian, French, Caro-Kann, Scandinavian, King's Pawn
        ["e7e5", "c7c5", "e7e6", "c7c6", "d7d5", "g8f6"],
        // After 1.d4: Queen's Gambit responses, Indian defenses
        ["d7d5", "g8f6", "e7e6", "c7c5", "f7f5"],
        // General strong first replies
        ["g8f6", "d7d5", "e7e6", "c7c6", "e7e5", "c7c5", "g7g6"]
    ];

    /**
     * Try to get an opening book move (first 12 half-moves).
     */
    static (Int, Int) getOpeningMove(GameRecord record) {
        if (record.moveHistory.size >= 12) {
            return (-1, -1);
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Int moveCount = record.moveHistory.size;

        Int[] validFroms = new Int[];
        Int[] validTos = new Int[];

        for (String[] responses : OPENING_RESPONSES) {
            for (String move : responses) {
                if (move.size != 4) {
                    continue;
                }
                Int fromFile = move[0] - 'a';
                Int fromRank = 8 - (move[1] - '0');
                Int toFile   = move[2] - 'a';
                Int toRank   = 8 - (move[3] - '0');
                Int from = fromRank * 8 + fromFile;
                Int to   = toRank   * 8 + toFile;

                if (from < 0 || from >= 64 || to < 0 || to >= 64) {
                    continue;
                }

                Char piece = board[from];
                if (piece == '.' || BoardUtils.colorOf(piece) != Color.Black) {
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

                Char[] testBoard = BoardUtils.cloneBoard(board);
                testBoard[to] = piece;
                testBoard[from] = '.';
                if (CheckDetection.isInCheck(testBoard.freeze(), Color.Black)) {
                    continue;
                }

                validFroms = validFroms + from;
                validTos = validTos + to;
            }
        }

        if (validFroms.empty) {
            return (-1, -1);
        }

        Int index = hashRandom(moveCount * 1009, validFroms.size) % validFroms.size;
        return (validFroms[index], validTos[index]);
    }

    // ----- Best Move Selection -----------------------------------------------

    /**
     * Find the best move for the current position.
     *
     * Strategy by game phase:
     * 1. Opening (first ~12 half-moves): may use opening book
     * 2. Middlegame: 2-ply minimax with heuristic top-move diversity
     * 3. Endgame: 3-ply minimax for precise play
     *
     * @return (fromIndex, toIndex, promotion?) or (-1, -1, Null) if no moves
     */
    (Int, Int, String?) findBestMove(GameRecord record) {
        Int moveCount = record.moveHistory.size;

        // Try opening book first (70% chance in early game)
        (Int openFrom, Int openTo) = getOpeningMove(record);
        if (openFrom >= 0 && openTo >= 0) {
            if (hashRandom(moveCount, 1) % 100 < 70) {
                return (openFrom, openTo, Null);
            }
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Boolean endgame = isEndgame(board);
        Int depth = endgame ? 3 : 2;

        // Collect all legal moves with heuristic scores for ordering
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

        if (moveFroms.empty) {
            return (-1, -1, Null);
        }

        // Sort moves by heuristic score (descending) for better alpha-beta pruning
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

        // Minimax search with alpha-beta on sorted moves
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

            Int score = minimax(newBoard, record, depth - 1, alpha, beta, False);

            // Small variety to avoid repetitive play
            Int variety = hashRandom(from * 64 + to, moveCount + i) % 5;
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

    // ----- Fallback: Random Legal Move ---------------------------------------

    /**
     * Select a random legal move as a last-resort fallback.
     */
    static (Int, Int, String?) findRandomLegalMove(GameRecord record) {
        Char[] board = BoardUtils.cloneBoard(record.board);
        Int[] validFroms = new Int[];
        Int[] validTos   = new Int[];

        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != record.turn) {
                continue;
            }
            for (Int to : 0 ..< 64) {
                if (from == to) {
                    continue;
                }
                Char target = board[to];
                if (target != '.' && BoardUtils.colorOf(target) == record.turn) {
                    continue;
                }
                if (!PieceValidator.isLegal(piece, from, to, board,
                        record.castlingRights, record.enPassantTarget)) {
                    continue;
                }

                Char[] testBoard = BoardUtils.cloneBoard(board);
                testBoard[to]   = piece;
                testBoard[from] = '.';
                if (CheckDetection.isInCheck(testBoard.freeze(), record.turn)) {
                    continue;
                }

                validFroms = validFroms + from;
                validTos   = validTos   + to;
            }
        }

        if (validFroms.empty) {
            return (-1, -1, Null);
        }

        Int index = hashRandom(record.moveHistory.size, validFroms.size) % validFroms.size;
        return (validFroms[index], validTos[index], Null);
    }

    // ----- FEN Conversion (utility for logging/future API use) ---------------

    /**
     * Convert a GameRecord to FEN (Forsyth-Edwards Notation).
     */
    static String boardToFen(GameRecord record) {
        StringBuffer fen = new StringBuffer();

        for (Int rank = 0; rank < 8; rank++) {
            if (rank > 0) {
                fen.addAll("/");
            }
            Int emptyCount = 0;
            for (Int file = 0; file < 8; file++) {
                Char piece = record.board[rank * 8 + file];
                if (piece == '.') {
                    emptyCount++;
                } else {
                    if (emptyCount > 0) {
                        fen.addAll(emptyCount.toString());
                        emptyCount = 0;
                    }
                    fen.addAll(piece.toString());
                }
            }
            if (emptyCount > 0) {
                fen.addAll(emptyCount.toString());
            }
        }

        fen.addAll(record.turn == Color.White ? " w" : " b");

        StringBuffer castling = new StringBuffer();
        if (record.castlingRights.whiteKingside)  { castling.addAll("K"); }
        if (record.castlingRights.whiteQueenside) { castling.addAll("Q"); }
        if (record.castlingRights.blackKingside)  { castling.addAll("k"); }
        if (record.castlingRights.blackQueenside) { castling.addAll("q"); }
        if (castling.size == 0) {
            fen.addAll(" -");
        } else {
            fen.addAll(" ");
            fen.addAll(castling.toString());
        }

        if (record.enPassantTarget != Null) {
            fen.addAll(" ");
            fen.addAll(record.enPassantTarget.toString());
        } else {
            fen.addAll(" -");
        }
        fen.addAll(" ");
        fen.addAll(record.halfMoveClock.toString());

        Int fullmove = (record.moveHistory.size / 2) + 1;
        fen.addAll(" ");
        fen.addAll(fullmove.toString());

        return fen.toString();
    }
}
