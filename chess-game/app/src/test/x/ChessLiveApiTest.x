module ChessLiveApiTest {
    package chess import chess.examples.org;
    package web   import web.xtclang.org;

    import chess.api.ChessApi;
    import chess.api.ChessComApi;
    import chess.api.EngineApi;

    import web.responses.SimpleResponse;

    /**
     * End-to-end tests against the real upstream services: Stockfish Online and chess.com.
     *
     * These need an internet connection and are subject to the upstream rate limits, so they are
     * not part of the default run. Run them with `scripts/test.sh --live`.
     */
    class LiveApiTests {
        static String AFTER_E4 = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1";

        static String bodyOf(SimpleResponse response) = response.body?.bytes.unpackUtf8() : "";

        /**
         * Stockfish Online answers 429 to a burst; leave the documented gap between calls.
         */
        static void pace() {
            @Inject Clock clock;
            Time start = clock.now;
            while (clock.now - start < Duration.ofMillis(1600)) {}
        }

        @Test
        void shouldAnalyseAPositionWithTheEngine() {
            SimpleResponse response = new EngineApi().analyse(AFTER_E4, 10);
            String         body     = bodyOf(response);

            assert response.status == OK;
            assert body.indexOf("\"success\":true");
            assert body.indexOf("\"bestmove\":\"");
            assert body.indexOf("\"evaluation\":");
            pace();
        }

        @Test
        void shouldReturnTheEnginesMoveAsBoardIndices() {
            SimpleResponse response = new EngineApi().bestmove(AFTER_E4, 10);
            String         body     = bodyOf(response);

            assert response.status == OK;
            assert body.indexOf("\"fromSquare\":\"");
            assert body.indexOf("\"toSquare\":\"");
            pace();
        }

        @Test
        void shouldFetchTheChessComDailyPuzzle() {
            SimpleResponse response = new ChessComApi().puzzle();
            String         body     = bodyOf(response);

            assert response.status == OK;
            assert body.indexOf("\"fen\":");
        }

        @Test
        void shouldFetchAChessComProfile() {
            SimpleResponse response = new ChessComApi().player("hikaru");

            assert response.status == OK;
            assert bodyOf(response).indexOf("\"username\":");
        }

        @Test
        void shouldGetAReplyFromTheComputer() {
            @Inject Random random;
            ChessApi api = new ChessApi();
            String   id  = $"live-{random.int(1_000_000_000)}";

            api.move(id, "e2", "e4");

            // The server holds the reply back for its thinking delay, then asks the engine on the
            // first request after it. Poll the way the client does.
            @Inject Clock clock;
            Time started = clock.now;
            while (api.state(id).turn != "White") {
                assert clock.now - started < Duration.ofSeconds(30) as "No reply within 30s";
                Time pause = clock.now;
                while (clock.now - pause < Duration.ofMillis(500)) {}
            }

            val state = api.state(id);
            assert state.moveHistory.size == 2;
            assert state.moveHistory[1].color.toString() == "Black";
            assert state.fen.indexOf(" w ");
            pace();
        }
    }
}
