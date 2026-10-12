/**
 * Chess AI public entrypoint.
 *
 * Computer gameplay comes from the Stockfish Online API via [StockfishApi]; this service does
 * not choose moves of its own. The local evaluation and search services remain available to
 * callers that want a score for a position, and a random legal move is the only fallback when
 * the engine cannot be reached:
 * - StockfishApi: the engine that plays the computer's moves
 * - AIPositionEvaluator: board/position scoring, for reporting scores
 * - AISearchEngine: minimax + alpha-beta, for callers that ask for it explicitly
 * - AIOpeningBook: opening move suggestions, for callers that ask for it explicitly
 * - AIMoveSelector: legal move collection + ordering
 * - AIUtility: randomness, fallback move, FEN conversion
 */
service ChessAPIClient {
    // Shared score constants for search decisions.
    static Int MIN_SCORE       = -1000000;
    static Int MAX_SCORE       =  1000000;
    static Int CHECKMATE_SCORE =  100000;

    /**
     * Search depth asked of the engine for computer moves. Deeper play costs response time, and
     * the upstream API rejects anything over 15.
     */
    static Int SEARCH_DEPTH = 12;

    // The engine that plays every computer move
    StockfishApi engine = new StockfishApi();

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
     *
     * The move comes from the engine. It is still checked against this board's rules before
     * being returned, because the game uses a simplified rule set and cannot always play what
     * a full engine suggests (castling, for instance). An unusable or missing answer falls back
     * to a random legal move so that the game never stalls when the engine is unreachable.
     */
    (Int, Int, String?) findBestMove(GameRecord record) {
        String fen = AIUtility.boardToFen(record);
        StockfishApi.EngineMove move = engine.bestMove(fen, SEARCH_DEPTH);

        if (move.usable && isPlayable(record, move.fromIndex, move.toIndex)) {
            return (move.fromIndex, move.toIndex, move.promotion);
        }

        return AIUtility.findRandomLegalMove(record);
    }

    /**
     * Whether the side to move can legally play from one square to another under this game's
     * rules, and without leaving its own king in check.
     */
    private static Boolean isPlayable(GameRecord record, Int from, Int to) {
        if (!BoardUtils.isValidSquare(from) || !BoardUtils.isValidSquare(to) || from == to) {
            return False;
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Char   piece = board[from];
        if (piece == '.' || BoardUtils.colorOf(piece) != record.turn) {
            return False;
        }

        Char target = board[to];
        if (target != '.' && BoardUtils.colorOf(target) == record.turn) {
            return False;
        }
        if (!PieceValidator.isLegal(piece, from, to, board,
                record.castlingRights, record.enPassantTarget)) {
            return False;
        }

        Char[] tested = BoardUtils.cloneBoard(board);
        tested[to]   = piece;
        tested[from] = '.';
        return !CheckDetection.isInCheck(tested.freeze(), record.turn);
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
