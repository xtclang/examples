/**
 * Chess AI public entrypoint.
 *
 * Computer gameplay comes from the Stockfish Online API via [StockfishApi]; this service does
 * not choose moves of its own. A random legal move is the only fallback when the engine cannot
 * be reached:
 * - StockfishApi: the engine that plays the computer's moves
 * - AIUtility: randomness, fallback move, FEN conversion
 */
service ChessAPIClient {
    /**
     * Search depth asked of the engine for computer moves. Deeper play costs response time, and
     * the upstream API rejects anything over 15.
     */
    static Int SEARCH_DEPTH = 12;

    // The engine that plays every computer move
    StockfishApi engine = new StockfishApi();

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
}
