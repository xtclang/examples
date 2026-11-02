module EngineApiTest {
    package chess import chess.examples.org;
    package web   import web.xtclang.org;

    import chess.api.EngineApi;

    import web.responses.SimpleResponse;

    /**
     * Tests for the engine proxy (`/api/engine`): input that must be refused before any request
     * leaves the server, and the encoding of the engine's reply into JSON.
     *
     * Calls that actually reach Stockfish Online live in the opt-in `ChessLiveApiTest`.
     */
    class EngineApiTests {
        static String START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

        static String bodyOf(SimpleResponse response) = response.body?.bytes.unpackUtf8() : "";

        // ----- refused before reaching the engine ------------------------------------------------

        @Test
        void shouldRefuseToAnalyseSomethingThatIsNotAFen() {
            SimpleResponse response = new EngineApi().analyse("not a position", 10);

            assert response.status == BadRequest;
            assert bodyOf(response).indexOf("\"success\":false");
            assert bodyOf(response).indexOf("Invalid FEN");
        }

        @Test
        void shouldRefuseABestMoveRequestForSomethingThatIsNotAFen() {
            SimpleResponse response = new EngineApi().bestmove("8/8/8 w", 10);
            assert response.status == BadRequest;
        }

        // ----- what counts as a plausible FEN ----------------------------------------------------

        @Test
        void shouldAcceptRealPositions() {
            assert EngineApi.isPlausibleFen(START);
            assert EngineApi.isPlausibleFen("r4rk1/b4pp1/8/R2N4/1p5p/1P5P/4BPP1/6K1 w - - 0 1");
            assert EngineApi.isPlausibleFen("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 2");
        }

        @Test
        void shouldRejectMalformedPositions() {
            assert !EngineApi.isPlausibleFen("");
            assert !EngineApi.isPlausibleFen("short");
            assert !EngineApi.isPlausibleFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1"); // seven ranks
            assert !EngineApi.isPlausibleFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1");
            assert !EngineApi.isPlausibleFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR");    // no side to move
            assert !EngineApi.isPlausibleFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1\n");
            assert !EngineApi.isPlausibleFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ♞");
        }

        // ----- encoding the reply ----------------------------------------------------------------

        @Test
        void shouldPassNumbersThroughAndDropAnythingElse() {
            assert EngineApi.jsonNumber("0.46") == "0.46";
            assert EngineApi.jsonNumber("-3.2") == "-3.2";
            assert EngineApi.jsonNumber("1") == "1";
            assert EngineApi.jsonNumber(Null) == "null";
            assert EngineApi.jsonNumber("") == "null";
            assert EngineApi.jsonNumber("-") == "null";
            assert EngineApi.jsonNumber("1e9") == "null";
            assert EngineApi.jsonNumber("0.4,\"x\":1") == "null";
        }

        @Test
        void shouldQuotePlainTextAndRefuseAnythingThatCouldBreakTheJson() {
            assert EngineApi.jsonText("e7e5") == "\"e7e5\"";
            assert EngineApi.jsonText("e7e5 g1f3 b8c6") == "\"e7e5 g1f3 b8c6\"";
            assert EngineApi.jsonText(Null) == "null";
            assert EngineApi.jsonText("a\"b") == "null";
            assert EngineApi.jsonText("a\\b") == "null";
            assert EngineApi.jsonText("tab\there") == "null";
            assert EngineApi.jsonText("é") == "null";
        }

        @Test
        void shouldPullTheMoveOutOfABestMoveLine() {
            assert EngineApi.uciOf("bestmove e7e5 ponder g1f3") == "e7e5";
            assert EngineApi.uciOf("bestmove a7a8q") == "a7a8q";
            assert EngineApi.uciOf("bestmove") == Null;
            assert EngineApi.uciOf("") == Null;
            assert EngineApi.uciOf(Null) == Null;
        }
    }
}
