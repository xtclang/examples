import core.DraughtsGame;
import core.DraughtsGame.MoveOutcome;
import core.DraughtsRules.Move;
import core.Scoreboard;
import core.Scoreboard.ScoreTable;
import core.GameClock;
import db.models.TimeControl;
import db.models.MoveEntry;
import db.models.RoomRecord;
import api.DraughtsApi.MovesResponse;

/**
 * OnlineApi Service
 *
 * Rooms: a game two people play from their own devices. One player creates a room and shares its
 * code (or a link); the other joins with it. The creator plays Black and moves first, the joiner
 * plays White. Endpoints, all under /api/online:
 * - POST create                               open a room, as Black, optionally with clocks
 * - POST join/{roomCode}                      take the second seat, as White
 * - GET  state/{roomCode}/{playerId}          the room: the game, who you are, whose turn it is
 * - GET  moves/{roomCode}/{playerId}          your legal moves, when it is your turn
 * - POST move/{roomCode}/{playerId}/{path}    play a move, e.g. "c3-d4" or "c3-e5-g7"
 * - POST rematch/{roomCode}/{playerId}        a new game in the same room, once one has finished
 * - POST leave/{roomCode}/{playerId}          leave; leaving a game in progress forfeits it
 * - GET  scores/{roomCode}/{playerId}         the room's scoreboard, across all its games
 * - POST scores/{roomCode}/{playerId}/reset   clear it, once the game has ended
 *
 * A room can have clocks: each player has a bank of time that runs down only on their turn, with
 * an increment added after each of their moves (see GameClock). Nothing ticks on the server: a
 * player whose time has run out loses the next time anyone asks about the room.
 *
 * Each player is known by a private id handed out when they create or join, which their browser
 * keeps and sends with every request: only the two seated players can move. Clients poll `state`
 * to see the other player's moves.
 */
@WebService("/api/online")
service OnlineApi {
    // Database access; see the Database service in draughts.x
    @Lazy DraughtsSchema schema.calc() = Database.connect();
    @Inject Clock  clock;
    @Inject Random random;

    static String CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static String ID_CHARS   = "abcdefghijklmnopqrstuvwxyz0123456789";

    /**
     * POST /api/online/create
     *
     * Opens a room. The creator plays Black and gets the room code to share.
     */
    @Post("create")
    @Produces(Json)
    @HttpsRequired
    RoomState createRoom(@BodyParam NameRequest? request = Null) {
        using (schema.createTransaction()) {
            String code;
            do {
                code = randomText(CODE_CHARS, 6);
            } while (schema.rooms.contains(code));

            String   playerId = randomText(ID_CHARS, 16);
            GameRecord game   = DraughtsGame.newGame(request?.name : "Black", "White");
            TimeControl? clocks = request == Null
                    ? Null
                    : GameClock.start(clock.now, request.timeControlMs, request.incrementMs);
            RoomRecord room   = new RoomRecord(code, game, playerId, Null, Null, clocks);
            schema.rooms.put(code, room);
            return stateFor(room, playerId, Null);
        }
    }

    /**
     * Request body for creating or joining a room. Only a creator's `timeControlMs` (each player's
     * starting time; 0 for no clock) and `incrementMs` (added after each move) are used.
     */
    static const NameRequest(String name = "", Int timeControlMs = 0, Int incrementMs = 0);

    /**
     * POST /api/online/join/{roomCode}
     *
     * Takes the second seat in a room, as White.
     */
    @Post("join/{roomCode}")
    @Produces(Json)
    @HttpsRequired
    RoomState joinRoom(String roomCode, @BodyParam NameRequest? request = Null) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return notFound(roomCode);
            }
            room = settle(roomCode, room);
            if (room.whiteId != Null) {
                return refuse(room, "", "This room is full.");
            }
            GameRecord game = room.game;
            String playerId = randomText(ID_CHARS, 16);
            GameRecord seated = new GameRecord(game.board, game.turn, game.status, game.blackName,
                    DraughtsGame.cleanName(request?.name : "", "White"), game.quietPlies,
                    game.lastMove, game.history, game.level);
            RoomRecord joined = new RoomRecord(roomCode, seated, room.blackId, playerId, room.leftId,
                                               room.timeControl, room.timedOut);
            schema.rooms.put(roomCode, joined);
            return stateFor(joined, playerId, "You joined the room. You are White.");
        }
    }

    /**
     * GET /api/online/state/{roomCode}/{playerId}
     *
     * The room as this player sees it.
     */
    @Get("state/{roomCode}/{playerId}")
    @Produces(Json)
    @HttpsRequired
    RoomState state(String roomCode, String playerId) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return notFound(roomCode);
            }
            room = settle(roomCode, room);
            return stateFor(room, playerId, Null);
        }
    }

    /**
     * GET /api/online/moves/{roomCode}/{playerId}
     *
     * Every legal move for this player, each as the path the piece takes; none unless it is their
     * turn.
     */
    @Get("moves/{roomCode}/{playerId}")
    @Produces(Json)
    @HttpsRequired
    MovesResponse legalMoves(String roomCode, String playerId) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return new MovesResponse(False, "Room not found", []);
            }
            room = settle(roomCode, room);
            if (!isYourTurn(room, playerId)) {
                return new MovesResponse(False, "Not your turn", []);
            }
            String[] paths = new Array<String>();
            for (Move move : DraughtsRules.legalMoves(room.game.board, room.game.turn)) {
                paths.add(move.pathText);
            }
            return new MovesResponse(True, Null, paths.freeze(inPlace=True));
        }
    }

    /**
     * POST /api/online/move/{roomCode}/{playerId}/{path}
     *
     * Plays a move for this player.
     */
    @Post("move/{roomCode}/{playerId}/{path}")
    @Produces(Json)
    @HttpsRequired
    RoomState move(String roomCode, String playerId, String path) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return notFound(roomCode);
            }
            room = settle(roomCode, room);
            Color? mine = colorOf(room, playerId);
            if (mine == Null) {
                return refuse(room, playerId, "You are not a player in this room.");
            }
            if (room.whiteId == Null) {
                return refuse(room, playerId, "Waiting for an opponent to join.");
            }
            if (room.game.status != Ongoing) {
                return stateFor(room, playerId, Null, False); // says how it ended, e.g. on time
            }
            if (room.game.turn != mine) {
                return refuse(room, playerId, "It is not your turn.");
            }
            try {
                MoveOutcome result = DraughtsGame.applyMove(room.game, path);
                if (!result.ok) {
                    return refuse(room, playerId, result.message);
                }
                TimeControl? tc = room.timeControl;
                RoomRecord updated = new RoomRecord(roomCode, result.record, room.blackId,
                        room.whiteId, room.leftId,
                        tc == Null ? Null
                                   : GameClock.afterMove(tc, mine, room.game.history.empty, clock.now),
                        room.timedOut);
                schema.rooms.put(roomCode, updated);
                if (result.record.status != Ongoing) {
                    Scoreboard.record(schema, Scoreboard.roomScope(roomCode), result.record);
                }
                return stateFor(updated, playerId, Null);
            } catch (Exception e) {
                return refuse(room, playerId, $"Server error: {e.toString()}");
            }
        }
    }

    /**
     * POST /api/online/rematch/{roomCode}/{playerId}
     *
     * A fresh game in the same room, with both players still seated. Only once a game has ended,
     * and only while both are still there.
     */
    @Post("rematch/{roomCode}/{playerId}")
    @Produces(Json)
    @HttpsRequired
    RoomState rematch(String roomCode, String playerId) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return notFound(roomCode);
            }
            room = settle(roomCode, room);
            if (colorOf(room, playerId) == Null) {
                return refuse(room, playerId, "You are not a player in this room.");
            }
            if (room.game.status == Ongoing) {
                return refuse(room, playerId, "The game is not over yet.");
            }
            if (room.leftId != Null || room.whiteId == Null) {
                return refuse(room, playerId, "The other player has left.");
            }
            GameRecord fresh   = DraughtsGame.newGame(room.game.blackName, room.game.whiteName);
            TimeControl? before = room.timeControl;
            RoomRecord updated = new RoomRecord(roomCode, fresh, room.blackId, room.whiteId, Null,
                    before == Null ? Null
                                   : GameClock.start(clock.now, before.initialMs, before.incrementMs),
                    False);
            schema.rooms.put(roomCode, updated);
            return stateFor(updated, playerId, "New game started.");
        }
    }

    /**
     * POST /api/online/leave/{roomCode}/{playerId}
     *
     * Leaves the room. Leaving a game in progress forfeits it, and the other player wins. A room
     * nobody has joined is simply closed.
     */
    @Post("leave/{roomCode}/{playerId}")
    @Produces(Json)
    @HttpsRequired
    RoomState leave(String roomCode, String playerId) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return notFound(roomCode);
            }
            room = settle(roomCode, room);
            Color? mine = colorOf(room, playerId);
            if (mine == Null) {
                return refuse(room, playerId, "You are not a player in this room.");
            }
            if (room.whiteId == Null) {
                schema.rooms.remove(roomCode);
                return new RoomState(True, "Room closed.", roomCode);
            }
            if (room.leftId != Null) {
                return stateFor(room, playerId, Null); // already left
            }

            GameRecord game = room.game;
            if (game.status == Ongoing) {
                GameStatus forfeit = mine == Black ? WhiteWins : BlackWins;
                game = new GameRecord(game.board, game.turn, forfeit, game.blackName, game.whiteName,
                                      game.quietPlies, game.lastMove, game.history, game.level);
                Scoreboard.record(schema, Scoreboard.roomScope(roomCode), game);
            }
            RoomRecord updated = new RoomRecord(roomCode, game, room.blackId, room.whiteId, playerId,
                                                room.timeControl, room.timedOut);
            schema.rooms.put(roomCode, updated);
            return stateFor(updated, playerId, "You left the room.");
        }
    }

    /**
     * GET /api/online/scores/{roomCode}/{playerId}
     *
     * The room's scoreboard: every game its two players have finished here, rematch after
     * rematch, best first.
     */
    @Get("scores/{roomCode}/{playerId}")
    @Produces(Json)
    @HttpsRequired
    ScoreTable scores(String roomCode, String playerId) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return new ScoreTable([], False, $"Room {roomCode} was not found.");
            }
            if (colorOf(room, playerId) == Null) {
                return new ScoreTable([], False, "You are not a player in this room.");
            }
            room = settle(roomCode, room); // a game lost on time counts as soon as it is asked about
            return Scoreboard.table(schema, Scoreboard.roomScope(roomCode));
        }
    }

    /**
     * POST /api/online/scores/{roomCode}/{playerId}/reset
     *
     * Clears the room's scoreboard, for both players, once the game has ended (or before it has
     * begun).
     */
    @Post("scores/{roomCode}/{playerId}/reset")
    @Produces(Json)
    @HttpsRequired
    ScoreTable resetScores(String roomCode, String playerId) {
        using (schema.createTransaction()) {
            RoomRecord room;
            if (!(room := schema.rooms.get(roomCode))) {
                return new ScoreTable([], False, $"Room {roomCode} was not found.");
            }
            if (colorOf(room, playerId) == Null) {
                return new ScoreTable([], False, "You are not a player in this room.");
            }
            room = settle(roomCode, room);
            String scope = Scoreboard.roomScope(roomCode);
            if (!Scoreboard.canReset(room.game)) {
                return new ScoreTable(Scoreboard.table(schema, scope).table, False,
                                      "Finish the game before resetting the scoreboard.");
            }
            Scoreboard.reset(schema, scope);
            return Scoreboard.table(schema, scope);
        }
    }

    /**
     * The room as one player sees it, as sent to the web client.
     *
     * @param success       False if the request was refused; `message` says why
     * @param message       Human-readable status message for display
     * @param roomCode      The room's code
     * @param playerId      This player's private id, echoed back (it is only ever sent to them)
     * @param color         "Black" or "White": the side this player has; "" if not in the room
     * @param waiting       True while no second player has joined
     * @param opponentLeft  True if the other player has left
     * @param yourTurn      True if this player is to move
     * @param board         8 strings, one per row, row 0 (the top of the screen) first
     * @param turn          "Black" or "White": whose move it is
     * @param status        "Ongoing", "BlackWins", "WhiteWins" or "Draw"
     * @param lastMove      The last move's path, or Null
     * @param mustCapture   True if this player is to move and has a capture to make
     * @param history       Every move so far
     * @param timed         True if the room has clocks
     * @param blackMs       Black's time left right now, in milliseconds
     * @param whiteMs       White's time left right now, in milliseconds
     * @param incrementMs   Time added after each move
     * @param clockRunning  True while a clock is counting down (a timed game under way)
     */
    static const RoomState(Boolean success,
                           String message,
                           String roomCode = "",
                           String playerId = "",
                           String color = "",
                           Boolean waiting = False,
                           Boolean opponentLeft = False,
                           Boolean yourTurn = False,
                           String[] board = [],
                           String turn = "Black",
                           String status = "Ongoing",
                           String? lastMove = Null,
                           String blackName = "Black",
                           String whiteName = "White",
                           Int blackPieces = 12,
                           Int whitePieces = 12,
                           Boolean mustCapture = False,
                           MoveEntry[] history = [],
                           Boolean timed = False,
                           Int blackMs = 0,
                           Int whiteMs = 0,
                           Int incrementMs = 0,
                           Boolean clockRunning = False);

    // ----- Helper Methods ------------------------------------------------------

    /**
     * Which side a player has in a room, or Null if they are not in it.
     */
    Color? colorOf(RoomRecord room, String playerId) {
        if (playerId == room.blackId) {
            return Black;
        }
        String? white = room.whiteId;
        return white != Null && white == playerId ? White : Null;
    }

    Boolean isYourTurn(RoomRecord room, String playerId) {
        return room.whiteId != Null
                && room.game.status == Ongoing
                && colorOf(room, playerId) == room.game.turn;
    }

    /**
     * A random string of `size` characters drawn from `chars`.
     */
    String randomText(String chars, Int size) {
        StringBuffer buf = new StringBuffer();
        for (Int i : 0 ..< size) {
            buf.append(chars[random.int(chars.size)]);
        }
        return buf.toString();
    }

    RoomState notFound(String roomCode) {
        return new RoomState(False, $"Room {roomCode} was not found.", roomCode);
    }

    /**
     * The room's current state, with a message saying why a request was refused.
     */
    RoomState refuse(RoomRecord room, String playerId, String message) {
        return stateFor(room, playerId, message, False);
    }

    /**
     * If the player to move has run out of time, end the game: the other player wins, and the
     * result goes on the scoreboard. Called on every request that reads a room, since nothing
     * else is watching the clocks.
     */
    RoomRecord settle(String roomCode, RoomRecord room) {
        TimeControl? tc   = room.timeControl;
        GameRecord   game = room.game;
        if (tc == Null || room.whiteId == Null || game.status != Ongoing
                || !GameClock.timedOut(tc, game.turn, !game.history.empty, clock.now)) {
            return room;
        }
        GameRecord over = new GameRecord(game.board, game.turn,
                game.turn == Black ? WhiteWins : BlackWins, game.blackName, game.whiteName,
                game.quietPlies, game.lastMove, game.history, game.level);
        RoomRecord settled = new RoomRecord(roomCode, over, room.blackId, room.whiteId, room.leftId,
                // the clock of the player who ran out reads zero
                game.turn == Black
                        ? new TimeControl(tc.initialMs, tc.incrementMs, 0, tc.whiteMs, clock.now)
                        : new TimeControl(tc.initialMs, tc.incrementMs, tc.blackMs, 0, clock.now),
                True);
        schema.rooms.put(roomCode, settled);
        Scoreboard.record(schema, Scoreboard.roomScope(roomCode), over);
        return settled;
    }

    RoomState stateFor(RoomRecord room, String playerId, String? message, Boolean success = True) {
        GameRecord game    = room.game;
        Color?     mine    = colorOf(room, playerId);
        Boolean    waiting = room.whiteId == Null;
        Boolean    yours   = isYourTurn(room, playerId);
        Boolean    capture = yours
                && DraughtsRules.legalMoves(game.board, game.turn)[0].captures.size > 0;
        Boolean    ongoing = game.status == Ongoing;

        TimeControl? tc      = room.timeControl;
        Boolean      running = tc != Null && !waiting && ongoing && !game.history.empty;
        Time         now     = clock.now;

        String text;
        if (message != Null) {
            text = message;
        } else if (waiting) {
            text = $"Waiting for an opponent. Share the code {room.code}.";
        } else if (room.timedOut) {
            String loser  = game.status == WhiteWins ? game.blackName : game.whiteName;
            String winner = game.status == WhiteWins ? game.whiteName : game.blackName;
            text = $"{loser} ran out of time, so {winner} wins.";
        } else if (room.leftId != Null) {
            String leaver = room.leftId == room.blackId ? game.blackName : game.whiteName;
            String winner = room.leftId == room.blackId ? game.whiteName : game.blackName;
            text = ongoing ? $"{leaver} left the game." : $"{leaver} left, so {winner} wins.";
        } else if (!ongoing) {
            text = DraughtsGame.describeState(game, False);
        } else if (yours) {
            text = capture ? "Your move - you must capture." : "Your move.";
        } else {
            String name = game.turn == Black ? game.blackName : game.whiteName;
            text = $"{name} to move.";
        }

        return new RoomState(success, text, room.code,
                mine == Null ? "" : playerId,
                mine?.toString() : "",
                waiting, room.leftId != Null, yours,
                DraughtsGame.boardRows(game.board),
                game.turn.toString(), game.status.toString(), game.lastMove,
                game.blackName, game.whiteName,
                DraughtsRules.countPieces(game.board, Black),
                DraughtsRules.countPieces(game.board, White),
                capture, game.history,
                tc != Null,
                tc == Null ? 0 : GameClock.remaining(tc, Black, game.turn, running, now),
                tc == Null ? 0 : GameClock.remaining(tc, White, game.turn, running, now),
                tc == Null ? 0 : tc.incrementMs,
                running);
    }
}
