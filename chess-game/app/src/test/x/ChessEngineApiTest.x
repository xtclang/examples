module ChessEngineApiTest {
    package chess import chess.examples.org;

    import chess.ai.StockfishApi;
    import chess.utils.BoardUtils;

    /**
     * Tests for the Stockfish Online client's pure helpers: reading the engine's JSON reply,
     * turning a UCI `bestmove` line into board indices, and escaping a FEN for a query string.
     *
     * Nothing here reaches the network; the live call is exercised by running the app.
     */
    class StockfishApiTests {
        static String OK_REPLY =
            "{\"success\":true,\"evaluation\":0.46,\"mate\":null," +
            "\"bestmove\":\"bestmove e7e5 ponder g1f3\",\"continuation\":\"e7e5 g1f3 b8c6\"}";

        static String MATE_REPLY =
            "{\"success\":true,\"evaluation\":null,\"mate\":\"1\"," +
            "\"bestmove\":\"bestmove e1e8\",\"continuation\":\"e1e8\"}";

        // Note the space after the comma: the API sends this form on a rejected request.
        static String ERROR_REPLY = "{\"success\":false, \"error\":\"Invalid FEN\"}";

        @Test
        void shouldReadStringAndNumberFields() {
            assert StockfishApi.jsonField(OK_REPLY, "success") == "true";
            assert StockfishApi.jsonField(OK_REPLY, "evaluation") == "0.46";
            assert StockfishApi.jsonField(OK_REPLY, "bestmove") == "bestmove e7e5 ponder g1f3";
            assert StockfishApi.jsonField(OK_REPLY, "continuation") == "e7e5 g1f3 b8c6";
        }

        @Test
        void shouldReadNullAndMissingFieldsAsNull() {
            assert StockfishApi.jsonField(OK_REPLY, "mate") == Null;
            assert StockfishApi.jsonField(OK_REPLY, "nonesuch") == Null;
            assert StockfishApi.jsonField(MATE_REPLY, "evaluation") == Null;
            assert StockfishApi.jsonField(MATE_REPLY, "mate") == "1";
        }

        @Test
        void shouldReadARejectedRequest() {
            assert StockfishApi.jsonField(ERROR_REPLY, "success") == "false";
            assert StockfishApi.jsonField(ERROR_REPLY, "error") == "Invalid FEN";
        }

        @Test
        void shouldParseABestMoveLineIntoBoardIndices() {
            val move = StockfishApi.parseBestMove("bestmove e7e5 ponder g1f3");
            assert move.usable;
            assert BoardUtils.toAlgebraic(move.fromIndex) == "e7";
            assert BoardUtils.toAlgebraic(move.toIndex) == "e5";
            assert move.promotion == Null;
        }

        @Test
        void shouldParseAPromotion() {
            val move = StockfishApi.parseBestMove("bestmove a7a8q");
            assert move.usable;
            assert BoardUtils.toAlgebraic(move.fromIndex) == "a7";
            assert BoardUtils.toAlgebraic(move.toIndex) == "a8";
            assert move.promotion == "q";
        }

        @Test
        void shouldRejectAnAnswerWithNoMove() {
            assert !StockfishApi.parseBestMove("bestmove (none)").usable;
            assert !StockfishApi.parseBestMove("bestmove").usable;
            assert !StockfishApi.parseBestMove("").usable;
            assert !StockfishApi.parseBestMove("bestmove z9z9").usable;
        }

        @Test
        void shouldEscapeAFenForAQueryString() {
            assert StockfishApi.urlEncode("rnbq/8 w KQkq - 0 1") == "rnbq%2F8%20w%20KQkq%20-%200%201";
            assert StockfishApi.urlEncode("abcXYZ019-_.~") == "abcXYZ019-_.~";
        }
    }
}
