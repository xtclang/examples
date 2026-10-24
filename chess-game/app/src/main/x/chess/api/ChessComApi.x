import web.HttpClient;
import web.RequestOut;
import web.ResponseIn;
import web.responses.SimpleResponse;
/**
 * ChessComApi Service
 *
 * Read-only proxy for the chess.com Published-Data API (https://api.chess.com/pub).
 * The browser cannot call chess.com directly without depending on their CORS policy,
 * so the web client goes through this service. Responses are passed through as JSON.
 *
 * Endpoints:
 * - GET /api/chesscom/player/{username}
 * - GET /api/chesscom/archives/{username}
 * - GET /api/chesscom/games/{username}/{year}/{month}
 * - GET /api/chesscom/puzzle
 */
@WebService("/api/chesscom")
service ChessComApi {
    static String BASE_URI   = "https://api.chess.com/pub";
    static String USER_AGENT = "xtc-chess-game-example";

    // Reused across requests; HttpClient is a const and holds no per-request state
    HttpClient client = new HttpClient();

    /**
     * GET /api/chesscom/player/{username}
     *
     * @return the player's chess.com profile
     */
    @Get("player/{username}")
    @Produces(Json)
    @HttpsRequired
    SimpleResponse player(String username) {
        if (!isValidUsername(username)) {
            return badRequest("Invalid username");
        }
        return fetch($"{BASE_URI}/player/{username.toLowercase()}");
    }

    /**
     * GET /api/chesscom/archives/{username}
     *
     * @return the list of monthly game archive URLs for the player
     */
    @Get("archives/{username}")
    @Produces(Json)
    @HttpsRequired
    SimpleResponse archives(String username) {
        if (!isValidUsername(username)) {
            return badRequest("Invalid username");
        }
        return fetch($"{BASE_URI}/player/{username.toLowercase()}/games/archives");
    }

    /**
     * GET /api/chesscom/games/{username}/{year}/{month}
     *
     * @return the player's games for the month, including PGN and final FEN
     */
    @Get("games/{username}/{year}/{month}")
    @Produces(Json)
    @HttpsRequired
    SimpleResponse games(String username, String year, String month) {
        if (!isValidUsername(username) || !isDigits(year, 4) || !isDigits(month, 2)) {
            return badRequest("Invalid username, year or month");
        }
        return fetch($"{BASE_URI}/player/{username.toLowercase()}/games/{year}/{month}");
    }

    /**
     * GET /api/chesscom/puzzle
     *
     * @return the chess.com daily puzzle (title, FEN, PGN)
     */
    @Get("puzzle")
    @Produces(Json)
    @HttpsRequired
    SimpleResponse puzzle() {
        return fetch($"{BASE_URI}/puzzle");
    }

    // ----- helpers -------------------------------------------------------------------------------

    /**
     * Performs a GET against chess.com and relays the status and body.
     */
    private SimpleResponse fetch(String uri) {
        try {
            RequestOut request = client.createRequest(GET, new Uri(uri));
            request.header["User-Agent"] = USER_AGENT;
            request.header["Accept"]     = "application/json";

            ResponseIn response = client.send(request);
            Byte[]     bytes    = response.body?.bytes : [];
            return new SimpleResponse(response.status, Json, bytes);
        } catch (Exception e) {
            return new SimpleResponse(BadGateway, Json, errorBody("chess.com request failed"));
        }
    }

    private SimpleResponse badRequest(String message) {
        return new SimpleResponse(BadRequest, Json, errorBody(message));
    }

    private Byte[] errorBody(String message) {
        return ("{\"message\":\"" + message + "\"}").utf8();
    }

    /**
     * chess.com usernames are 3-25 characters: letters, digits, '_' and '-'. Anything else is
     * rejected so the value can never alter the upstream URL path.
     */
    static Boolean isValidUsername(String name) {
        if (name.size < 3 || name.size > 25) {
            return False;
        }
        for (Char ch : name) {
            if (!(ch.asciiLetter() || ch.asciiDigit() || ch == '_' || ch == '-')) {
                return False;
            }
        }
        return True;
    }

    static Boolean isDigits(String text, Int length) {
        if (text.size != length) {
            return False;
        }
        for (Char ch : text) {
            if (!ch.asciiDigit()) {
                return False;
            }
        }
        return True;
    }
}
