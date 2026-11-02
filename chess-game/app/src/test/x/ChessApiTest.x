module ChessApiTest {
    package chess import chess.examples.org;
    package db    import chessDB.examples.org;

    import chess.api.ChessApi;
    import chess.validation.ValidMovesHelper.ValidMovesResponse;

    /**
     * Endpoint tests for the single-player service (`/api`): state, move, valid moves and reset,
     * each called the way a request would call it, against a real database.
     *
     * The computer's reply needs its thinking delay to pass and the engine to answer, so it is
     * covered by the opt-in network suite, `ChessLiveApiTest`.
     */
    class ChessApiTests {
        static String START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

        /**
         * A session id no earlier run has used, so a test never inherits another's game.
         */
        static String freshSession(String label) {
            @Inject Random random;
            return $"{label}-{random.int(1_000_000_000)}";
        }

        @Test
        void shouldStartANewSessionAtTheInitialPosition() {
            ChessApi api   = new ChessApi();
            String   id    = freshSession("start");
            val      state = api.state(id);

            assert state.sessionId == id;
            assert state.turn == "White";
            assert state.status == "Ongoing";
            assert !state.opponentPending;
            assert state.moveHistory.empty;
            assert state.board[0] == "rnbqkbnr";
            assert state.board[7] == "RNBQKBNR";
            assert state.fen == START_FEN;
        }

        @Test
        void shouldReturnTheSameGameOnEveryRead() {
            ChessApi api = new ChessApi();
            String   id  = freshSession("reread");
            api.move(id, "e2", "e4");

            val first  = api.state(id);
            val second = api.state(id);
            assert first.fen == second.fen;
            assert first.moveHistory.size == 1;
        }

        @Test
        void shouldApplyALegalMoveAndHandTheTurnToTheComputer() {
            ChessApi api   = new ChessApi();
            String   id    = freshSession("legal");
            val      state = api.move(id, "e2", "e4");

            assert state.turn == "Black";
            assert state.lastMove == "e2e4";
            assert state.opponentPending;
            assert state.moveHistory.size == 1;
            assert state.moveHistory[0].fromSquare == "e2";
            assert state.moveHistory[0].toSquare == "e4";
            assert state.board[4] == "....P...";
            assert state.board[6] == "PPPP.PPP";
            assert state.fen.startsWith("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b");
        }

        @Test
        void shouldRejectAnIllegalMoveAndLeaveTheBoardAlone() {
            ChessApi api   = new ChessApi();
            String   id    = freshSession("illegal");
            val      state = api.move(id, "e2", "e5");

            assert state.turn == "White";
            assert state.moveHistory.empty;
            assert state.fen == START_FEN;
        }

        @Test
        void shouldRejectMovingTheComputersPieces() {
            ChessApi api   = new ChessApi();
            String   id    = freshSession("theirs");
            val      state = api.move(id, "e7", "e5");

            assert state.turn == "White";
            assert state.moveHistory.empty;
            assert state.fen == START_FEN;
        }

        @Test
        void shouldListTheSquaresAPieceCanReach() {
            ChessApi           api   = new ChessApi();
            String             id    = freshSession("valid");
            ValidMovesResponse pawn  = api.getValidMoves(id, "e2");
            ValidMovesResponse night = api.getValidMoves(id, "g1");

            assert pawn.success;
            assert pawn.validMoves.size == 2;
            assert pawn.validMoves.contains("e3") && pawn.validMoves.contains("e4");

            assert night.success;
            assert night.validMoves.size == 2;
            assert night.validMoves.contains("f3") && night.validMoves.contains("h3");
        }

        @Test
        void shouldListNothingForAnEmptySquareOrABlackPiece() {
            ChessApi api = new ChessApi();
            String   id  = freshSession("nothing");

            assert api.getValidMoves(id, "e4").validMoves.empty;
            assert api.getValidMoves(id, "e7").validMoves.empty;
        }

        @Test
        void shouldOfferNoMovesWhileTheComputerIsToMove() {
            ChessApi api = new ChessApi();
            String   id  = freshSession("blackturn");
            api.move(id, "e2", "e4");

            ValidMovesResponse reply = api.getValidMoves(id, "d2");
            assert !reply.success;
            assert reply.validMoves.empty;
        }

        @Test
        void shouldResetToTheInitialPosition() {
            ChessApi api = new ChessApi();
            String   id  = freshSession("reset");
            api.move(id, "e2", "e4");

            val state = api.reset(id);
            assert state.fen == START_FEN;
            assert state.moveHistory.empty;
            assert !state.opponentPending;
            assert state.timeControl == Null;
        }

        @Test
        void shouldStartAClockWhenResetWithATimeControl() {
            ChessApi api   = new ChessApi();
            String   id    = freshSession("clock");
            val      state = api.reset(id, new ChessApi.ResetRequest(300_000, 5_000));

            assert val clock ?= state.timeControl;
            assert clock.whiteTimeMs == 300_000;
            assert clock.blackTimeMs == 300_000;
            assert clock.incrementMs == 5_000;
        }

        @Test
        void shouldKeepSessionsIndependent() {
            ChessApi api   = new ChessApi();
            String   one   = freshSession("one");
            String   two   = freshSession("two");
            api.move(one, "e2", "e4");

            assert api.state(one).moveHistory.size == 1;
            assert api.state(two).moveHistory.empty;
            assert api.state(two).fen == START_FEN;
        }
    }
}
