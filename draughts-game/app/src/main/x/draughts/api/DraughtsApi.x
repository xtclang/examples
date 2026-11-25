import core.DraughtsGame;
import core.DraughtsGame.MoveOutcome;
import core.DraughtsRules.Move;
import core.Scoreboard;
import core.Scoreboard.ScoreTable;
import db.models.GameStatus;
import db.models.MoveEntry;
import db.models.ScoreEntry;

/**
 * DraughtsApi Service
 *
 * RESTful API for playing draughts, against the computer (which plays White, at a chosen level)
 * or against a second person taking turns at the same screen. The server holds the game, enforces
 * the rules, chooses the computer's moves, and tells the client what the board looks like and where
 * each piece may go. Endpoints:
 * - GET  /api/state/{sessionId}                  the current game
 * - POST /api/new/{sessionId}                    start a new game, with the two nicknames
 * - GET  /api/moves/{sessionId}                  every legal move for the player to move
 * - POST /api/move/{sessionId}/{path}            play a move, e.g. "c3-d4" or "c3-e5-g7"
 * - POST /api/computer/{sessionId}               the computer plays its move, when it is its turn
 * - GET  /api/scores/{sessionId}                this session's scoreboard
 * - POST /api/scores/{sessionId}/reset           clear it, once the game has ended
 *
 * When a game ends, each player's result goes on the session's own scoreboard, which `scores`
 * reads and `resetScores` clears. The scoreboard shares this service because the platform allows
 * only one web service per path.
 * All operations are transactional. Each browser session gets its own game via a session id.
 */
@WebService("/api")
service DraughtsApi {
    // Database access; see the Database service in draughts.x
    @Lazy DraughtsSchema schema.calc() = Database.connect();
    @Inject Clock  clock;
    @Inject Random random;

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
            return SessionHelper.toApiState(SessionHelper.ensureGame(schema, sessionId), Null, sessionId);
        }
    }

    /**
     * POST /api/new/{sessionId}
     *
     * Starts a new game for this session, replacing any game in progress.
     *
     * @param request the nicknames and, to play the computer, its level; all may be left out
     */
    @Post("new/{sessionId}")
    @Produces(Json)
    @HttpsRequired
    ApiState newGame(String sessionId, @BodyParam NewGameRequest? request = Null) {
        using (schema.createTransaction()) {
            GameRecord game = request == Null
                    ? DraughtsGame.newGame()
                    : DraughtsGame.newGame(request.black, request.white, request.level);
            schema.games.put(sessionId, game);
            return SessionHelper.toApiState(game, "New game started", sessionId);
        }
    }

    /**
     * Request body for starting a game. A `level` of "easy", "medium" or "hard" plays the
     * computer (the second nickname is then ignored); "" plays a second person.
     */
    static const NewGameRequest(String black = "Black", String white = "White", String level = "");

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
            GameRecord game = SessionHelper.ensureGame(schema, sessionId);
            if (game.status != Ongoing) {
                return new MovesResponse(False, "Game already finished", []);
            }
            if (DraughtsGame.computerToMove(game)) {
                return new MovesResponse(False, "It is the computer's turn", []);
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
            GameRecord game = SessionHelper.ensureGame(schema, sessionId);
            try {
                MoveOutcome result = DraughtsGame.applyMove(game, path);
                if (!result.ok) {
                    return SessionHelper.toApiState(game, result.message, sessionId);
                }
                schema.games.put(sessionId, result.record);
                if (result.record.status != Ongoing) {
                    SessionHelper.recordResult(schema, sessionId, result.record);
                }
                return SessionHelper.toApiState(result.record, Null, sessionId);
            } catch (Exception e) {
                return SessionHelper.toApiState(game, $"Server error: {e.toString()}", sessionId);
            }
        }
    }

    /**
     * POST /api/computer/{sessionId}
     *
     * The computer plays its move, if it is its turn. The client calls this after showing the
     * player's own move, so the reply is something the player sees happen. If it is not the
     * computer's turn the game comes back unchanged.
     */
    @Post("computer/{sessionId}")
    @Produces(Json)
    @HttpsRequired
    ApiState computerMove(String sessionId) {
        using (schema.createTransaction()) {
            GameRecord game = SessionHelper.ensureGame(schema, sessionId);
            if (!DraughtsGame.computerToMove(game)) {
                return SessionHelper.toApiState(game, Null, sessionId);
            }
            try {
                MoveOutcome result = DraughtsGame.applyComputerMove(game, random);
                if (!result.ok) {
                    return SessionHelper.toApiState(game, result.message, sessionId);
                }
                schema.games.put(sessionId, result.record);
                if (result.record.status != Ongoing) {
                    SessionHelper.recordResult(schema, sessionId, result.record);
                }
                return SessionHelper.toApiState(result.record, Null, sessionId);
            } catch (Exception e) {
                return SessionHelper.toApiState(game, $"Server error: {e.toString()}", sessionId);
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
     * @param level       "" for two players, else the computer's level: "easy", "medium" or "hard"
     * @param computerToMove True if the computer is to move: the client should now ask for it
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
                          String sessionId = "",
                          String level = "",
                          Boolean computerToMove = False);

    /**
     * GET /api/scores/{sessionId}
     *
     * This session's scoreboard: the results of every game finished in it, best first.
     */
    @Get("scores/{sessionId}")
    @Produces(Json)
    @HttpsRequired
    ScoreTable scores(String sessionId) {
        using (schema.createTransaction()) {
            return Scoreboard.table(schema, Scoreboard.sessionScope(sessionId));
        }
    }

    /**
     * POST /api/scores/{sessionId}/reset
     *
     * Clears this session's scoreboard, once its game has ended (or before it has begun); a game
     * in progress would be left with a scoreboard that forgets the games before it.
     */
    @Post("scores/{sessionId}/reset")
    @Produces(Json)
    @HttpsRequired
    ScoreTable resetScores(String sessionId) {
        using (schema.createTransaction()) {
            String scope = Scoreboard.sessionScope(sessionId);
            if (!Scoreboard.canReset(SessionHelper.ensureGame(schema, sessionId))) {
                return new ScoreTable(Scoreboard.table(schema, scope).table, False,
                                      "Finish the game before resetting the scoreboard.");
            }
            Scoreboard.reset(schema, scope);
            return Scoreboard.table(schema, scope);
        }
    }
}
