import core.DraughtsGame;
import core.DraughtsGame.MoveOutcome;
import core.DraughtsRules.Move;
import db.models.GameStatus;
import db.models.MoveEntry;
import db.models.ScoreEntry;

/**
 * DraughtsApi Service
 *
 * RESTful API for playing draughts. Two people take turns at one screen; the server holds the
 * game, enforces the rules and tells the client what the board looks like and where each piece
 * may go. Endpoints:
 * - GET  /api/state/{sessionId}                  the current game
 * - POST /api/new/{sessionId}                    start a new game, with the two nicknames
 * - GET  /api/moves/{sessionId}                  every legal move for the player to move
 * - POST /api/move/{sessionId}/{path}            play a move, e.g. "c3-d4" or "c3-e5-g7"
 *
 * When a game ends, each player's result goes on the day's scoreboard (see ScoresApi).
 * All operations are transactional. Each browser session gets its own game via a session id.
 */
@WebService("/api")
service DraughtsApi {
    // Database access; see the Database service in draughts.x
    @Lazy DraughtsSchema schema.calc() = Database.connect();
    @Inject Clock clock;

    /**
     * GET /api/state/{sessionId}
     *
     * The current game for this session, creating a fresh one if there is none yet.
     */
    @Get("state/{sessionId}")
    @Produces(Json)
    @HttpsRequired
    ApiState state(String sessionId) {
        using (schema.createTransaction()) {
            return toApiState(ensureGame(sessionId), Null, sessionId);
        }
    }

    /**
     * POST /api/new/{sessionId}
     *
     * Starts a new game for this session, replacing any game in progress.
     *
     * @param request the two nicknames; either may be left out
     */
    @Post("new/{sessionId}")
    @Produces(Json)
    @HttpsRequired
    ApiState newGame(String sessionId, @BodyParam NewGameRequest? request = Null) {
        using (schema.createTransaction()) {
            GameRecord game = request == Null
                    ? DraughtsGame.newGame()
                    : DraughtsGame.newGame(request.black, request.white);
            schema.games.put(sessionId, game);
            return toApiState(game, "New game started", sessionId);
        }
    }

    /**
     * Request body for starting a game.
     */
    static const NewGameRequest(String black = "Black", String white = "White");

    /**
     * GET /api/moves/{sessionId}
     *
     * Every legal move for the player to move, each as the path the piece takes. Because captures
     * are compulsory, if any capture exists these are all captures. A multi-jump is one move, so
     * the client can follow a piece through its jumps by matching the path so far.
     */
    @Get("moves/{sessionId}")
    @Produces(Json)
    @HttpsRequired
    MovesResponse legalMoves(String sessionId) {
        using (schema.createTransaction()) {
            GameRecord game = ensureGame(sessionId);
            if (game.status != Ongoing) {
                return new MovesResponse(False, "Game already finished", []);
            }
            String[] paths = new Array<String>();
            for (Move move : DraughtsRules.legalMoves(game.board, game.turn)) {
                paths.add(move.pathText);
            }
            return new MovesResponse(True, Null, paths.freeze(inPlace=True));
        }
    }

    /**
     * Response for the legal-moves query.
     */
    static const MovesResponse(Boolean success, String? error, String[] moves);

    /**
     * POST /api/move/{sessionId}/{path}
     *
     * Plays a move for whichever player is to move.
     *
     * @param path the squares the piece visits, joined by "-"
     * @return the game after the move, or unchanged with a message if the move was illegal
     */
    @Post("move/{sessionId}/{path}")
    @Produces(Json)
    @HttpsRequired
    ApiState move(String sessionId, String path) {
        using (schema.createTransaction()) {
            GameRecord game = ensureGame(sessionId);
            try {
                MoveOutcome result = DraughtsGame.applyMove(game, path);
                if (!result.ok) {
                    return toApiState(game, result.message, sessionId);
                }
                schema.games.put(sessionId, result.record);
                if (result.record.status != Ongoing) {
                    recordResult(result.record);
                }
                return toApiState(result.record, Null, sessionId);
            } catch (Exception e) {
                return toApiState(game, $"Server error: {e.toString()}", sessionId);
            }
        }
    }

    /**
     * The complete game state, as sent to the web client.
     *
     * @param board       8 strings, one per row, row 0 (the top of the screen) first
     * @param turn        "Black" or "White": whose move it is
     * @param status      "Ongoing", "BlackWins", "WhiteWins" or "Draw"
     * @param message     Human-readable status message for display
     * @param lastMove    The last move's path (e.g. "c3-e5"), or Null
     * @param blackName   Nickname of the Black player
     * @param whiteName   Nickname of the White player
     * @param blackPieces How many pieces Black has left
     * @param whitePieces How many pieces White has left
     * @param mustCapture True if the player to move has a capture, so must make one
     * @param history     Every move so far
     * @param sessionId   Echo of the session id
     */
    static const ApiState(String[] board,
                          String turn,
                          String status,
                          String message,
                          String? lastMove,
                          String blackName,
                          String whiteName,
                          Int blackPieces,
                          Int whitePieces,
                          Boolean mustCapture,
                          MoveEntry[] history,
                          String sessionId = "");

    // ----- Helper Methods ------------------------------------------------------

    /**
     * The game for a session, created in the starting position if there is none.
     */
    GameRecord ensureGame(String sessionId) {
        if (GameRecord game := schema.games.get(sessionId)) {
            return game;
        }
        GameRecord fresh = DraughtsGame.newGame();
        schema.games.put(sessionId, fresh);
        return fresh;
    }

    /**
     * Put a finished game on today's scoreboard, one result for each player.
     */
    void recordResult(GameRecord game) {
        String today  = clock.now.date.toString();
        Color? winner = DraughtsGame.winnerOf(game.status);
        addScore(today, game.blackName, winner == Black, winner == Null);
        addScore(today, game.whiteName, winner == White, winner == Null);
    }

    private void addScore(String date, String name, Boolean win, Boolean draw) {
        String     key     = DraughtsGame.scoreKey(date, name);
        ScoreEntry current = schema.scores.getOrDefault(key, new ScoreEntry(name));
        schema.scores.put(key, current.record(win, draw));
    }

    /**
     * Converts a GameRecord to the API response format.
     */
    ApiState toApiState(GameRecord game, String? message = Null, String sessionId = "") {
        Boolean ongoing     = game.status == Ongoing;
        Boolean mustCapture = ongoing
                && DraughtsRules.legalMoves(game.board, game.turn)[0].captures.size > 0;
        return new ApiState(
                DraughtsGame.boardRows(game.board),
                game.turn.toString(),
                game.status.toString(),
                message ?: describeState(game, mustCapture),
                game.lastMove,
                game.blackName,
                game.whiteName,
                DraughtsRules.countPieces(game.board, Black),
                DraughtsRules.countPieces(game.board, White),
                mustCapture,
                game.history,
                sessionId);
    }

    /**
     * A human-readable description of the game for the status line.
     */
    String describeState(GameRecord game, Boolean mustCapture) {
        switch (game.status) {
        case BlackWins:
            return $"{game.blackName} (Black) wins: {game.whiteName} has no legal moves left.";
        case WhiteWins:
            return $"{game.whiteName} (White) wins: {game.blackName} has no legal moves left.";
        case Draw:
            return "Draw: 40 moves each without a capture or a man moving.";
        default:
            break;
        }
        String name = game.turn == Black ? game.blackName : game.whiteName;
        return mustCapture ? $"{name} to move - you must capture." : $"{name} to move.";
    }
}
