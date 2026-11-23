module DraughtsApiTest {
    package draughts import draughts.examples.org;
    package db       import draughtsDB.examples.org;

    import draughts.api.DraughtsApi;
    import draughts.api.ScoresApi;

    import db.models.Color;
    import db.models.GameRecord;
    import db.models.GameStatus;

    /**
     * Endpoint tests for the game service (`/api`): state, new game, legal moves and move, each
     * called the way a request would call it, against a real database.
     */
    class DraughtsApiTests {
        static String START_TOP    = ".w.w.w.w";
        static String START_BOTTOM = "b.b.b.b.";

        /**
         * A name no earlier run has used, so a test never inherits another's game or scores.
         */
        static String fresh(String label) {
            @Inject Random random;
            return $"{label}{random.int(1_000_000_000)}";
        }

        @Test
        void shouldStartANewSessionAtTheInitialPosition() {
            DraughtsApi api   = new DraughtsApi();
            String      id    = fresh("start");
            val         state = api.state(id);

            assert state.sessionId == id;
            assert state.turn == "Black";
            assert state.status == "Ongoing";
            assert state.history.empty;
            assert state.board.size == 8;
            assert state.board[0] == START_TOP;
            assert state.board[7] == START_BOTTOM;
            assert state.blackPieces == 12;
            assert state.whitePieces == 12;
            assert !state.mustCapture;
            assert state.message == "Black to move.";
        }

        @Test
        void shouldListTheSevenOpeningMoves() {
            DraughtsApi api   = new DraughtsApi();
            val         reply = api.legalMoves(fresh("moves"));

            assert reply.success;
            assert reply.moves.size == 7;
            assert reply.moves.any(m -> m == "c3-d4");
            assert reply.moves.any(m -> m == "g3-h4");
        }

        @Test
        void shouldPlayALegalMoveAndHandOverTheTurn() {
            DraughtsApi api   = new DraughtsApi();
            String      id    = fresh("legal");
            val         state = api.move(id, "c3-d4");

            assert state.turn == "White";
            assert state.lastMove == "c3-d4";
            assert state.history.size == 1;
            assert state.history[0].notation == "c3-d4";
            assert state.history[0].path == "c3-d4";
            assert state.board[4] == "...b....";
            assert state.board[5] == "b...b.b.";
            assert state.message == "White to move.";
        }

        @Test
        void shouldAlternateTurnsBetweenThePlayers() {
            DraughtsApi api = new DraughtsApi();
            String      id  = fresh("alternate");
            api.move(id, "c3-d4");
            val state = api.move(id, "b6-a5");

            assert state.turn == "Black";
            assert state.history.size == 2;
            assert state.history[1].color == White;
        }

        @Test
        void shouldRefuseAnIllegalMoveAndLeaveTheBoardAlone() {
            DraughtsApi api    = new DraughtsApi();
            String      id     = fresh("illegal");
            val         before = api.state(id);

            // Not a diagonal step; a piece that is not yours; an empty square; nonsense
            for (String bad : ["c3-c4", "b6-a5", "d4-e5", "zz-yy", "c3"]) {
                val after = api.move(id, bad);
                assert after.turn == "Black";
                assert after.history.empty;
                assert after.board == before.board;
                assert after.message != "";
            }
        }

        @Test
        void shouldKeepEachSessionSeparate() {
            DraughtsApi api = new DraughtsApi();
            String      one = fresh("one");
            String      two = fresh("two");
            api.move(one, "c3-d4");

            assert api.state(one).history.size == 1;
            assert api.state(two).history.empty;
        }

        @Test
        void shouldReturnTheSameGameOnEveryRead() {
            DraughtsApi api = new DraughtsApi();
            String      id  = fresh("reread");
            api.move(id, "e3-f4");

            assert api.state(id).board == api.state(id).board;
            assert api.state(id).history.size == 1;
        }

        @Test
        void shouldStartANewGameWithNicknames() {
            DraughtsApi api = new DraughtsApi();
            String      id  = fresh("new");
            api.move(id, "c3-d4");

            val state = api.newGame(id, new DraughtsApi.NewGameRequest("  Ann  ", "Bo"));
            assert state.blackName == "Ann";
            assert state.whiteName == "Bo";
            assert state.history.empty;
            assert state.turn == "Black";
            assert state.message == "New game started";
            assert api.state(id).message == "Ann to move.";
        }

        @Test
        void shouldFallBackToDefaultNicknamesAndLimitLongOnes() {
            DraughtsApi api   = new DraughtsApi();
            val         state = api.newGame(fresh("names"),
                    new DraughtsApi.NewGameRequest("   ", "abcdefghijklmnopqrstuvwxyz"));
            assert state.blackName == "Black";
            assert state.whiteName == "abcdefghijklmnopqrst";
        }

        @Test
        void shouldForceACaptureAndRefuseAStep() {
            DraughtsApi api = new DraughtsApi();
            String      id  = fresh("capture");
            // Black c3-d4, then White f6-e5 steps next to it, leaving Black a capture.
            api.move(id, "c3-d4");
            api.move(id, "f6-e5");
            val state = api.state(id);

            // White's man on e5 can be taken by the Black man on d4
            assert state.mustCapture;
            assert state.message == "Black to move - you must capture.";
            val moves = api.legalMoves(id);
            assert moves.moves.size == 1;
            assert moves.moves[0] == "d4-f6";

            val refused = api.move(id, "e3-f4");
            assert refused.history.size == 2;
            assert refused.message == "Illegal move: you must capture.";

            val taken = api.move(id, "d4-f6");
            assert taken.history.size == 3;
            assert taken.history[2].captures == 1;
            assert taken.history[2].notation == "d4xf6";
            assert taken.whitePieces == 11;
        }

        @Test
        void shouldEndTheGameAndRecordTheResultsOnTheScoreboard() {
            DraughtsApi api  = new DraughtsApi();
            String      id   = fresh("finish");
            String      ann  = fresh("Ann");
            String      bo   = fresh("Bo");

            // Position: one Black man a jump from the last White piece.
            String board = "........" + "..w....." + ".b......" + "........" +
                           "........" + "........" + "........" + "........";
            using (api.schema.createTransaction()) {
                api.schema.games.put(id, new GameRecord(board, Black, Ongoing, ann, bo));
            }

            val state = api.move(id, "b6-d8");
            assert state.status == "BlackWins";
            assert state.whitePieces == 0;
            assert state.message.startsWith($"{ann} (Black) wins");

            // The finished game takes no more moves
            val after = api.move(id, "d8-e7");
            assert after.status == "BlackWins";
            assert after.message == "Game already finished";

            val table = new ScoresApi().scores().table;
            Int found = 0;
            for (val row : table) {
                if (row.name == ann) {
                    assert row.played == 1 && row.won == 1 && row.lost == 0 && row.points == 3;
                    ++found;
                } else if (row.name == bo) {
                    assert row.played == 1 && row.won == 0 && row.lost == 1 && row.points == 0;
                    ++found;
                }
            }
            assert found == 2;
        }

        @Test
        void shouldPlayTheComputerAtAChosenLevel() {
            DraughtsApi api = new DraughtsApi();
            String      id  = fresh("vsai");

            val state = api.newGame(id, new DraughtsApi.NewGameRequest("Ann", "ignored", "medium"));
            assert state.level == "medium";
            assert state.blackName == "Ann";
            assert state.whiteName == "Computer (Medium)";
            assert !state.computerToMove;

            // The human's move hands the turn to the computer, which has not moved yet
            val after = api.move(id, "c3-d4");
            assert after.turn == "White";
            assert after.computerToMove;
            assert after.history.size == 1;
            assert after.message == "Computer (Medium) is thinking...";

            // Nobody else may move for the computer, and there are no moves to offer
            val refused = api.move(id, "b6-a5");
            assert refused.history.size == 1;
            assert refused.message == "It is the computer's turn";
            assert !api.legalMoves(id).success;

            // The computer replies when asked, and it is the human's turn again
            val reply = api.computerMove(id);
            assert reply.history.size == 2;
            assert reply.history[1].color == White;
            assert reply.turn == "Black";
            assert !reply.computerToMove;
            assert api.legalMoves(id).success;
        }

        @Test
        void shouldNotLetTheComputerMoveOutOfTurn() {
            DraughtsApi api = new DraughtsApi();
            String      id  = fresh("outofturn");
            api.newGame(id, new DraughtsApi.NewGameRequest("Ann", "", "easy"));

            // It is the human's turn, so asking for a computer move changes nothing
            val state = api.computerMove(id);
            assert state.history.empty;
            assert state.turn == "Black";

            // And a two-player game never has a computer
            String two = fresh("two");
            api.newGame(two, new DraughtsApi.NewGameRequest("Ann", "Bo", ""));
            api.move(two, "c3-d4");
            val s2 = api.computerMove(two);
            assert s2.history.size == 1;
            assert s2.level == "";
            assert !s2.computerToMove;
        }

        @Test
        void shouldPlayManyMovesAgainstTheComputerWithEveryMoveAccepted() {
            DraughtsApi api   = new DraughtsApi();
            String      id    = fresh("many");
            var         state = api.newGame(id, new DraughtsApi.NewGameRequest(fresh("Ann"), "", "easy"));

            // The human plays the first legal move each time; the computer answers.
            Int plies = 0;
            while (state.status == "Ongoing" && plies < 30) {
                Int before = state.history.size;
                if (state.computerToMove) {
                    state = api.computerMove(id);
                } else {
                    state = api.move(id, api.legalMoves(id).moves[0]);
                }
                assert state.history.size == before + 1;
                ++plies;
            }
            assert state.history.size == plies;
            for (Int i : 0 ..< state.history.size) {
                assert state.history[i].color == (i % 2 == 0 ? Black : White);
            }
        }
    }
}
