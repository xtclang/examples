import core.PgnReplay;
import core.PgnReplay.Frame;
import core.FenParser;
import validation.ValidMovesHelper;
import validation.ValidMovesHelper.ValidMovesResponse;

/**
 * PgnReplayApi Service
 *
 * Replays PGN movetext from an arbitrary starting FEN into the per-move frames the frontend
 * needs to step through a chess.com game or puzzle -- the one piece of chess.com data
 * [ChessComApi] deliberately never parses, since it's a pure pass-through proxy.
 *
 * Endpoints:
 * - POST /api/replay
 * - GET /api/replay/validmoves?fen={fen}&square={square}
 */
@WebService("/api/replay")
service PgnReplayApi {
    /**
     * POST /api/replay
     *
     * @param request the starting position and the PGN movetext to replay from it
     * @return one frame per position: the start, then one more per move actually applied
     */
    @Post
    @Produces(Json)
    @HttpsRequired
    Frame[] replay(@BodyParam ReplayRequest request) {
        return PgnReplay.replay(request.fen, request.pgn);
    }

    /**
     * Request body for replaying a PGN from a starting position.
     */
    static const ReplayRequest(String fen, String pgn);

    /**
     * GET /api/replay/validmoves?fen={fen}&square={square}
     *
     * The puzzle/replay equivalent of [ChessApi.getValidMoves]: legal destination squares for a
     * piece in an arbitrary position, rather than the active session's game.
     *
     * @param fen    the position to look up legal moves in
     * @param square the square containing the piece (e.g., "e2")
     * @return a ValidMovesResponse with the array of legal destination squares
     */
    @Get("validmoves")
    @Produces(Json)
    @HttpsRequired
    ValidMovesResponse validMoves(@QueryParam String fen, @QueryParam String square) {
        GameRecord record = FenParser.fromFen(fen);
        String[] moves = ValidMovesHelper.getValidMoves(
                record.board, square, record.turn, record.castlingRights, record.enPassantTarget);
        return new ValidMovesResponse(True, Null, moves);
    }
}
