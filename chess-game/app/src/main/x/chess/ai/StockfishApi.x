import web.HttpClient;
import web.RequestOut;
import web.ResponseIn;
/**
 * Stockfish Online client.
 *
 * All computer gameplay comes from this API; nothing in this service decides a move on its own.
 * The upstream endpoint is https://stockfish.online/api/s/v2.php, which answers for any legal
 * FEN with:
 *
 *     {"success":true,"evaluation":0.46,"mate":null,
 *      "bestmove":"bestmove e7e5 ponder g1f3","continuation":"e7e5 g1f3 b8c6 ..."}
 *
 * or, on a rejected request:
 *
 *     {"success":false,"error":"Invalid FEN"}
 *
 * Numbers are relayed as text so that this service never has to interpret them; the only field
 * it reads is `bestmove`, which it turns into a pair of board indices for the game logic.
 */
service StockfishApi {
    static String BASE_URI     = "https://stockfish.online/api/s/v2.php";
    static String USER_AGENT   = "xtc-chess-game-example";

    /**
     * Search depth used for computer moves. The upstream API rejects anything over 15, and the
     * response time grows quickly with depth, so this sits in the middle of the usable range.
     */
    static Int DEFAULT_DEPTH = 12;
    static Int MAX_DEPTH     = 15;
    static Int MIN_DEPTH     = 1;

    // Nibble-to-hex lookup used by urlEncode
    static String HEX_DIGITS = "0123456789ABCDEF";

    // Reused across requests; HttpClient is a const and holds no per-request state
    HttpClient client = new HttpClient();

    /**
     * One answer from the engine. Every numeric field is kept as text, exactly as the API sent
     * it: `evaluation` is in pawns from White's point of view and is Null in a forced mate,
     * where `mate` carries the signed distance to mate instead.
     */
    static const EngineReply(Boolean success,
                             String? bestMove     = Null,
                             String? evaluation   = Null,
                             String? mate         = Null,
                             String? continuation = Null,
                             String? error        = Null);

    /**
     * A move as the game logic needs it: two board indices plus an optional promotion piece.
     * Both indices are -1 when the engine gave no usable move.
     */
    static const EngineMove(Int fromIndex, Int toIndex, String? promotion = Null) {
        @RO Boolean usable.get() = fromIndex >= 0 && toIndex >= 0;
    }

    /**
     * Asks the engine to analyse a position.
     *
     * @param fen    the position in Forsyth-Edwards notation
     * @param depth  search depth, clamped to the range the API accepts
     *
     * @return the engine's reply, or an unsuccessful reply if the API could not be reached
     */
    EngineReply analyse(String fen, Int depth = DEFAULT_DEPTH) {
        Int    safeDepth = depth.notLessThan(MIN_DEPTH).notGreaterThan(MAX_DEPTH);
        String uri       = $"{BASE_URI}?fen={urlEncode(fen)}&depth={safeDepth}";

        String json;
        try {
            RequestOut request = client.createRequest(GET, new Uri(uri));
            request.header["User-Agent"] = USER_AGENT;
            request.header["Accept"]     = "application/json";

            ResponseIn response = client.send(request);
            Byte[]     bytes    = response.body?.bytes : [];
            json = bytes.unpackUtf8();
        } catch (Exception e) {
            return new EngineReply(False, error = "Stockfish request failed");
        }

        if (jsonField(json, "success") != "true") {
            return new EngineReply(False, error = jsonField(json, "error") ?: "Engine declined");
        }

        return new EngineReply(True,
                               bestMove     = jsonField(json, "bestmove"),
                               evaluation   = jsonField(json, "evaluation"),
                               mate         = jsonField(json, "mate"),
                               continuation = jsonField(json, "continuation"));
    }

    /**
     * Asks the engine for the move to play in a position.
     *
     * @return the engine's move, or an unusable move if the engine gave no answer
     */
    EngineMove bestMove(String fen, Int depth = DEFAULT_DEPTH) {
        EngineReply reply = analyse(fen, depth);
        if (String line ?= reply.bestMove) {
            return parseBestMove(line);
        }
        return new EngineMove(-1, -1);
    }

    // ----- parsing -------------------------------------------------------------------------------

    /**
     * Pulls the move out of a UCI `bestmove` line, e.g. "bestmove e7e5 ponder g1f3" or
     * "bestmove a7a8q". A missing or malformed move yields an unusable [EngineMove].
     */
    static EngineMove parseBestMove(String line) {
        String uci = "";
        for (String token : line.split(' ')) {
            String trimmed = token.trim();
            if (trimmed.size >= 4 && trimmed != "bestmove" && trimmed != "ponder") {
                uci = trimmed;
                break;
            }
        }
        if (uci.size < 4) {
            return new EngineMove(-1, -1);
        }

        Int from = BoardUtils.parseSquare(uci[0 ..< 2]);
        Int to   = BoardUtils.parseSquare(uci[2 ..< 4]);
        if (from < 0 || to < 0) {
            return new EngineMove(-1, -1);
        }

        String? promotion = uci.size > 4 ? uci[4 ..< 5].toLowercase() : Null;
        return new EngineMove(from, to, promotion);
    }

    /**
     * Reads one field out of the flat JSON object the API returns. Quoted strings come back
     * unquoted; bare numbers and booleans come back as their text; `null` and absent fields come
     * back as Null.
     */
    static String? jsonField(String json, String name) {
        String needle = $"\"{name}\"";
        if (Int keyAt := json.indexOf(needle)) {
            Int cursor = keyAt + needle.size;
            while (cursor < json.size && (json[cursor] == ' ' || json[cursor] == ':')) {
                cursor++;
            }
            if (cursor >= json.size) {
                return Null;
            }

            if (json[cursor] == '"') {
                cursor++;
                Int start = cursor;
                while (cursor < json.size && json[cursor] != '"') {
                    cursor++;
                }
                return json[start ..< cursor];
            }

            Int start = cursor;
            while (cursor < json.size && json[cursor] != ',' && json[cursor] != '}') {
                cursor++;
            }
            String raw = json[start ..< cursor].trim();
            return raw == "null" || raw.size == 0 ? Null : raw;
        }
        return Null;
    }

    /**
     * Percent-encodes everything outside the unreserved set, so a FEN -- which contains spaces
     * and slashes -- can be carried in a query string.
     */
    static String urlEncode(String text) {
        StringBuffer encoded = new StringBuffer();
        for (Char ch : text) {
            if (ch.asciiLetter() || ch.asciiDigit() || ch == '-' || ch == '_' || ch == '.' || ch == '~') {
                encoded.add(ch);
            } else {
                Int code = ch.codepoint.toInt();
                encoded.add('%');
                encoded.add(HEX_DIGITS[(code & 0xF0) >> 4]);
                encoded.add(HEX_DIGITS[code & 0x0F]);
            }
        }
        return encoded.toString();
    }
}
