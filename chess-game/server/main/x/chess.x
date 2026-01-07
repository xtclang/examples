@WebApp
module chess.examples.org {
    package db     import chessDB.examples.org;
    package logic  import chessLogic.examples.org;
    package web    import web.xtclang.org;

    import web.*;
    import db.ChessSchema;
    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
    import logic.*;

    /** Serve the static client. */
    @StaticContent("/", /public/index.html)
    service Home {}

    /**
     * Basic API for a turn-based chess game.
     * This intentionally keeps the rules lean (no castling, en-passant, or check detection).
     */
    @WebService("/api")
    service ChessApi {
        @Inject ChessSchema schema;
        @Inject Clock         clock;

        @Atomic private Boolean pendingActive;
        @Atomic private Time    pendingStart;
        @Atomic private Boolean autoApplied;

        @RO Duration moveDelay.get() = Duration.ofSeconds(3);

        @Get("state")
        @Produces(Json)
        ApiState state() {
            using (schema.createTransaction()) {
                GameRecord record = ensureGame();
                GameRecord updated = maybeResolveAuto(record);
                if (autoApplied) {
                    saveGame(updated);
                }
                return toApiState(updated, Null);
            }
        }

        @Post("move/{from}/{target}")
        @Produces(Json)
        ApiState move(String from, String target) {
            using (schema.createTransaction()) {
                GameRecord record = ensureGame();
                try {
                    MoveOutcome result = ChessLogic.applyHumanMove(record, from, target, Null);
                    if (result.ok) {
                        GameRecord current = maybeResolveAuto(result.record);
                        saveGame(current);
                        return toApiState(current, Null);
                    }
                    return toApiState(result.record, result.message);
                } catch (Exception e) {
                    return toApiState(record, $"Server error: {e.toString()}");
                }
            }
        }

        @Post("reset")
        @Produces(Json)
        ApiState reset() {
            using (schema.createTransaction()) {
                schema.games.remove(gameId);
                GameRecord reset = ChessLogic.resetGame();
                schema.games.put(gameId, reset);
                pendingActive = False;
                autoApplied   = False;
                return toApiState(reset, "New game started");
            }
        }

        // ----- helpers ------------------------------------------------------

        @RO Int gameId.get() = 1;

        GameRecord ensureGame() {
            GameRecord record = schema.games.getOrDefault(gameId, ChessLogic.defaultGame());
            if (!schema.games.contains(gameId)) {
                schema.games.put(gameId, record);
            }
            return record;
        }

        void saveGame(GameRecord record) {
            schema.games.put(gameId, record);
        }

        ApiState toApiState(GameRecord record, String? message = Null) {
            Boolean pending = pendingActive && isOpponentPending(record);
            String  detail  = message ?: describeState(record, pending);
            return new ApiState(
                    ChessLogic.boardRows(record.board),
                    record.turn.toString(),
                    record.status.toString(),
                    detail,
                    record.lastMove,
                    record.playerScore,
                    record.opponentScore,
                    pending);
        }

        Boolean isOpponentPending(GameRecord record) {
            return record.status == GameStatus.Ongoing && record.turn == Color.Black;
        }

        String describeState(GameRecord record, Boolean pending) {
            switch (record.status) {
            case GameStatus.Checkmate:
                return record.turn == Color.White
                        ? "Opponent captured all your pieces. Game over."
                        : "You captured every opponent piece. Victory!";

            case GameStatus.Stalemate:
                return "Only kings remain. Stalemate.";

            default:
                break;
            }

            String? move = record.lastMove;
            if (pending) {
                return move == Null
                        ? "Opponent thinking..."
                        : $"You moved {move}. Opponent thinking...";
            }

            if (record.turn == Color.White) {
                return move == Null
                        ? "Your move."
                        : $"Opponent moved {move}. Your move.";
            }

            return "Your move.";
        }

        GameRecord maybeResolveAuto(GameRecord record) {
            autoApplied = False;

            if (!isOpponentPending(record)) {
                pendingActive = False;
                return record;
            }

            Time now = clock.now;
            if (!pendingActive) {
                pendingActive = True;
                pendingStart  = now;
                return record;
            }

            Duration waited = now - pendingStart;
            if (waited >= moveDelay) {
                AutoResponse reply = ChessLogic.autoMove(record);
                pendingActive = False;
                autoApplied   = True;
                return reply.record;
            }

            return record;
        }
    }

    const ApiState(String[] board,
                   String turn,
                   String status,
                   String message,
                   String? lastMove,
                   Int playerScore,
                   Int opponentScore,
                   Boolean opponentPending);
}
