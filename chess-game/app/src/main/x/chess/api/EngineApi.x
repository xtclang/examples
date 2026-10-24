import ai.StockfishApi;
import web.responses.SimpleResponse;
/**
 * EngineApi Service
 *
 * Exposes the Stockfish Online engine to the web client. The browser never calls the engine
 * directly: every request goes through here, so the upstream URL, user agent, depth limits and
 * failure handling live in one place -- the same arrangement [ChessComApi] uses for chess.com.
 *
 * Endpoints:
 * - GET /api/engine/analyse?fen={fen}&depth={depth}
 * - GET /api/engine/bestmove?fen={fen}&depth={depth}
 */
@WebService("/api/engine")
service EngineApi {
    StockfishApi engine = new StockfishApi();

    /**
     * GET /api/engine/analyse?fen={fen}&depth={depth}
     *
     * Analyses a position. `evaluation` is in pawns from White's point of view, and is null in a
     * forced mate, where `mate` carries the distance to mate instead.
     *
     * @param fen    the position in Forsyth-Edwards notation
     * @param depth  search depth, clamped to 1..15
     *
     * @return the engine's evaluation, best move and principal variation as JSON
     */
    @Get("analyse")
    @Produces(Json)
    @HttpsRequired
    SimpleResponse analyse(@QueryParam String fen,
                           @QueryParam Int    depth = StockfishApi.DEFAULT_DEPTH) {
        if (!isPlausibleFen(fen)) {
            return error(BadRequest, "Invalid FEN");
        }

        StockfishApi.EngineReply reply = engine.analyse(fen, depth);
        if (!reply.success) {
            return error(BadGateway, reply.error ?: "Engine unavailable");
        }

        StockfishApi.EngineMove move = StockfishApi.parseBestMove(reply.bestMove ?: "");

        StringBuffer body = new StringBuffer();
        body.addAll("{\"success\":true");
        addField(body, "evaluation", jsonNumber(reply.evaluation));
        addField(body, "mate", jsonNumber(reply.mate));
        addField(body, "bestmove", jsonText(uciOf(reply.bestMove)));
        addField(body, "from", move.fromIndex.toString());
        addField(body, "to", move.toIndex.toString());
        addField(body, "promotion", jsonText(move.promotion));
        addField(body, "continuation", jsonText(reply.continuation));
        body.addAll("}");
        return new SimpleResponse(OK, Json, body.toString().utf8());
    }

    /**
     * GET /api/engine/bestmove?fen={fen}&depth={depth}
     *
     * The move the engine would play, already converted to the board indices the game uses.
     *
     * @param fen    the position in Forsyth-Edwards notation
     * @param depth  search depth, clamped to 1..15
     *
     * @return the move as JSON
     */
    @Get("bestmove")
    @Produces(Json)
    @HttpsRequired
    SimpleResponse bestmove(@QueryParam String fen,
                            @QueryParam Int    depth = StockfishApi.DEFAULT_DEPTH) {
        if (!isPlausibleFen(fen)) {
            return error(BadRequest, "Invalid FEN");
        }

        StockfishApi.EngineMove move = engine.bestMove(fen, depth);
        if (!move.usable) {
            return error(BadGateway, "Engine returned no move");
        }

        StringBuffer body = new StringBuffer();
        body.addAll("{\"success\":true");
        addField(body, "from", move.fromIndex.toString());
        addField(body, "to", move.toIndex.toString());
        addField(body, "fromSquare", jsonText(BoardUtils.toAlgebraic(move.fromIndex)));
        addField(body, "toSquare", jsonText(BoardUtils.toAlgebraic(move.toIndex)));
        addField(body, "promotion", jsonText(move.promotion));
        body.addAll("}");
        return new SimpleResponse(OK, Json, body.toString().utf8());
    }

    // ----- helpers -------------------------------------------------------------------------------

    private SimpleResponse error(HttpStatus status, String message) {
        StringBuffer body = new StringBuffer();
        body.addAll("{\"success\":false");
        addField(body, "message", jsonText(message));
        body.addAll("}");
        return new SimpleResponse(status, Json, body.toString().utf8());
    }

    /**
     * Appends `,"name":value` to a JSON object being built. The value is already JSON-encoded.
     */
    private static void addField(StringBuffer body, String name, String value) {
        body.addAll(",\"");
        body.addAll(name);
        body.addAll("\":");
        body.addAll(value);
    }

    /**
     * Renders a value the engine sent as a number back as JSON: the digits as they arrived, or
     * `null`. Anything that is not a number is dropped rather than relayed.
     */
    static String jsonNumber(String? value) {
        if (String text ?= value) {
            Boolean digits = False;
            for (Char ch : text) {
                if (ch.asciiDigit()) {
                    digits = True;
                } else if (ch != '-' && ch != '+' && ch != '.') {
                    return "null";
                }
            }
            if (digits) {
                return text;
            }
        }
        return "null";
    }

    /**
     * Renders a string as a JSON string literal, or `null`. The engine only ever sends plain
     * ASCII moves and notation, so anything outside that set is dropped.
     */
    static String jsonText(String? value) {
        if (String text ?= value) {
            for (Char ch : text) {
                if (!ch.ascii || ch == '"' || ch == '\\' || ch.codepoint < 0x20) {
                    return "null";
                }
            }
            return $"\"{text}\"";
        }
        return "null";
    }

    /**
     * Pulls the plain UCI move out of a "bestmove e7e5 ponder g1f3" line.
     */
    static String? uciOf(String? bestMoveLine) {
        if (String line ?= bestMoveLine) {
            for (String token : line.split(' ')) {
                String trimmed = token.trim();
                if (trimmed.size >= 4 && trimmed != "bestmove" && trimmed != "ponder") {
                    return trimmed;
                }
            }
        }
        return Null;
    }

    /**
     * Cheap shape check so a malformed value is rejected here rather than upstream: a FEN is
     * ASCII, has a board field of eight '/'-separated ranks, and names the side to move.
     */
    static Boolean isPlausibleFen(String fen) {
        if (fen.size < 10 || fen.size > 120) {
            return False;
        }
        for (Char ch : fen) {
            if (!ch.ascii || ch.codepoint < 0x20) {
                return False;
            }
        }

        String[] fields = fen.trim().split(' ');
        if (fields.size < 2) {
            return False;
        }
        if (fields[0].split('/').size != 8) {
            return False;
        }
        return fields[1] == "w" || fields[1] == "b";
    }
}
