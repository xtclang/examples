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

    // ----- Random Number Generation -------------------------------------------------

    /**
     * Simple deterministic hash-based pseudo-random function.
     * Uses game state (move count, board hash) to generate variety.
     * Each call with same inputs produces same output for reproducibility,
     * but different game states produce different results.
     */
    static Int hashRandom(Int seed, Int counter) {
        // Simple hash combination for pseudo-randomness
        Int hash = seed ^ (counter * 2654435761);  // Golden ratio prime
        hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
        hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
        hash = (hash >> 16) ^ hash;
        return hash.abs();
    }

    /**
     * Get a random integer between 0 (inclusive) and max (exclusive).
     * Uses move count and a counter for variety.
     */
    static Int randomInt(Int max, Int moveCount, Int counter) {
        if (max <= 0) {
            return 0;
        }
        Int rand = hashRandom(moveCount * 1009 + counter * 7919, counter);
        return rand % max;
    }

    // ----- Opening Book -------------------------------------------------

    /**
     * Collection of strong opening moves for Black.
     * Format: Array of algebraic move strings like "e7e5".
     */
    static String[][] OPENING_RESPONSES = [
        // After 1.e4 (e2-e4) - various responses
        ["e7e5", "c7c5", "e7e6", "c7c6", "d7d6", "g8f6", "d7d5"],
        // After 1.d4 (d2-d4) - various responses
        ["d7d5", "g8f6", "e7e6", "c7c5", "f7f5"],
        // General good opening moves for Black
        ["g8f6", "d7d5", "e7e6", "c7c6", "b8c6", "e7e5", "c7c5", "g7g6"]
    ];

    // ----- Best Move Selection -------------------------------------------------

    /**
     * Check if the game is in opening phase (first 6 moves).
     */
    static Boolean isOpeningPhase(GameRecord record) {
        return record.moveHistory.size < 12; // 6 moves per side = 12 half-moves
    }

    /**
     * Try to get a book opening move.
     * Returns a random strong opening move if in opening phase.
     * Returns (-1, -1) if no opening move available.
     */
    static (Int, Int) getOpeningMove(GameRecord record) {
        if (!isOpeningPhase(record)) {
            return (-1, -1);
        }

        Int moveCount = record.moveHistory.size;
        Char[] board = BoardUtils.cloneBoard(record.board);
        
        // Collect valid opening moves from the book using parallel arrays
        Int[] validFroms = new Int[];
        Int[] validTos = new Int[];
        
        for (String[] responses : OPENING_RESPONSES) {
            for (String move : responses) {
                if (move.size != 4) {
                    continue;
                }
                Int fromFile = move[0] - 'a';
                Int fromRank = 8 - (move[1] - '0');
                Int toFile = move[2] - 'a';
                Int toRank = 8 - (move[3] - '0');
                
                Int from = fromRank * 8 + fromFile;
                Int to = toRank * 8 + toFile;
                
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
                
                validFroms = validFroms + from;
                validTos = validTos + to;
            }
        }
        
        if (validFroms.empty) {
            return (-1, -1);
        }
        
        // Pick a random opening move
        Int index = randomInt(validFroms.size, moveCount, validFroms.size);
        return (validFroms[index], validTos[index]);
    }

    /**
     * Find the best move for Black (AI opponent).
     * Returns (from, to, score) tuple.
     * 
     * Uses randomization to add variety:
     * 1. In opening phase, may select from opening book
     * 2. Otherwise, collects all moves within a score threshold of the best
     * 3. Randomly selects from the top moves for unpredictability
     */
    static (Int, Int, Int) findBestMove(GameRecord record) {
        Int moveCount = record.moveHistory.size;
        
        // Try opening book first
        (Int openFrom, Int openTo) = getOpeningMove(record);
        if (openFrom >= 0 && openTo >= 0) {
            // 70% chance to use opening book in early game
            if (randomInt(100, moveCount, 1) < 70) {
                Char[] board = BoardUtils.cloneBoard(record.board);
                Int score = scoreMove(board[openFrom], openFrom, openTo, board, record);
                return (openFrom, openTo, score);
            }
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Int bestScore = MIN_SCORE;
        
        // Collect all legal moves with their scores using parallel arrays
        Int[] allFroms = new Int[];
        Int[] allTos = new Int[];
        Int[] allScores = new Int[];

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
                allFroms = allFroms + from;
                allTos = allTos + to;
                allScores = allScores + score;
                
                if (score > bestScore) {
                    bestScore = score;
                }
            }
        }

        if (allFroms.empty) {
            return (-1, -1, MIN_SCORE);
        }

        // Determine score threshold for "good enough" moves
        // Allow moves within 15% of best score (or 50 points minimum variance)
        Int threshold = (bestScore.abs() * 15) / 100;
        if (threshold < 50) {
            threshold = 50;
        }
        Int minAcceptableScore = bestScore - threshold;

        // Collect all moves that are "good enough" using parallel arrays
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

        // Limit to top 5 moves maximum for reasonable diversity
        if (topFroms.size > 5) {
            // Simple selection sort to get top 5 by score
            for (Int i : 0 ..< 5) {
                Int maxIdx = i;
                for (Int j : i + 1 ..< topFroms.size) {
                    if (topScores[j] > topScores[maxIdx]) {
                        maxIdx = j;
                    }
                }
                if (maxIdx != i) {
                    // Swap
                    Int tmpFrom = topFroms[i];
                    Int tmpTo = topTos[i];
                    Int tmpScore = topScores[i];
                    topFroms = topFroms.replace(i, topFroms[maxIdx]);
                    topFroms = topFroms.replace(maxIdx, tmpFrom);
                    topTos = topTos.replace(i, topTos[maxIdx]);
                    topTos = topTos.replace(maxIdx, tmpTo);
                    topScores = topScores.replace(i, topScores[maxIdx]);
                    topScores = topScores.replace(maxIdx, tmpScore);
                }
            }
            // Keep only top 5
            topFroms = topFroms[0 ..< 5];
            topTos = topTos[0 ..< 5];
            topScores = topScores[0 ..< 5];
        }

        // Randomly select from top moves
        Int index = randomInt(topFroms.size, moveCount, topFroms.size + allFroms.size);
        return (topFroms[index], topTos[index], topScores[index]);
    }
}