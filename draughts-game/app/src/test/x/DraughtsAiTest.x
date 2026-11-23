module DraughtsAiTest {
    package draughts import draughts.examples.org;
    package db       import draughtsDB.examples.org;

    import draughts.core.DraughtsAi;
    import draughts.core.DraughtsGame;
    import draughts.core.DraughtsRules;
    import draughts.core.DraughtsRules.Move;

    import db.models.Color;

    static String EMPTY = "........";

    static String board(String r0, String r1, String r2, String r3,
                        String r4, String r5, String r6, String r7) {
        return r0 + r1 + r2 + r3 + r4 + r5 + r6 + r7;
    }

    /**
     * The levels and how a position is valued.
     */
    class LevelTests {
        @Test
        void shouldKnowThreeLevelsAndDefaultToMedium() {
            assert DraughtsAi.levelFor("easy").depth == 2;
            assert DraughtsAi.levelFor("medium").depth == 4;
            assert DraughtsAi.levelFor("hard").depth == 7;
            assert DraughtsAi.levelFor("hard").randomPercent == 0;
            assert DraughtsAi.levelFor("easy").randomPercent > DraughtsAi.levelFor("medium").randomPercent;
            assert DraughtsAi.levelFor("nonsense").name == "medium";
        }

        @Test
        void shouldNormalizeLevelNames() {
            assert DraughtsGame.normalizeLevel("") == "";
            assert DraughtsGame.normalizeLevel(Null) == "";
            assert DraughtsGame.normalizeLevel("easy") == "easy";
            assert DraughtsGame.normalizeLevel(" hard ") == "hard";
            assert DraughtsGame.normalizeLevel("bogus") == "medium";
        }

        @Test
        void shouldValueTheStartingPositionEqually() {
            String start = DraughtsRules.startingBoard();
            assert DraughtsAi.evaluate(start, Black) == 0;
            assert DraughtsAi.evaluate(start, White) == 0;
        }

        @Test
        void shouldValueAnExtraPieceAndAKing() {
            String man  = board(EMPTY, EMPTY, EMPTY, EMPTY, "...b....", EMPTY, EMPTY, "w.......");
            String king = board(EMPTY, EMPTY, EMPTY, EMPTY, "...B....", EMPTY, EMPTY, "w.......");
            assert DraughtsAi.evaluate(king, Black) > DraughtsAi.evaluate(man, Black);
            assert DraughtsAi.evaluate(man, Black) == -DraughtsAi.evaluate(man, White);
        }
    }

    /**
     * Choosing a move.
     */
    class MoveChoiceTests {
        @Test
        void shouldAlwaysPlayALegalMoveAtEveryLevel() {
            @Inject Random random;
            String start = DraughtsRules.startingBoard();
            for (String level : ["easy", "medium", "hard"]) {
                assert Move move := DraughtsAi.chooseMove(start, Black, level, random);
                assert DraughtsRules.findMove(start, Black, move.path);
            }
        }

        @Test
        void shouldReportNoMoveWhenThereIsNone() {
            @Inject Random random;
            String blocked = board(EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, "w.......");
            assert !DraughtsAi.chooseMove(blocked, White, "hard", random);
        }

        @Test
        void shouldPlayTheOnlyMoveItHas() {
            @Inject Random random;
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, "b.......");
            assert Move move := DraughtsAi.chooseMove(b, Black, "hard", random);
            assert move.path == [56, 49];
        }

        @Test
        void shouldTakeACompulsoryCaptureAtEveryLevel() {
            @Inject Random random;
            String b = board(EMPTY, EMPTY, EMPTY, "..w.....", "...b....", EMPTY, ".b......", EMPTY);
            for (String level : ["easy", "medium", "hard"]) {
                assert Move move := DraughtsAi.chooseMove(b, Black, level, random);
                assert move.captures == [26];
            }
        }

        @Test
        void shouldNotHangAPieceWhenPlayingHigh() {
            @Inject Random random;
            // The Black man on e4 can go to d5 (and be captured by the White man on c6) or to f5
            // (safe). Looking ahead, High must see that d5 loses the only piece.
            String b = board(EMPTY, EMPTY, EMPTY, "..w.....", EMPTY, "....b...", EMPTY, EMPTY);
            assert Move move := DraughtsAi.chooseMove(b, Black, "hard", random);
            assert move.path == [44, 37];
        }

        @Test
        void shouldFinishAWholeGameBetweenTwoComputersWithoutIllegalMoves() {
            @Inject Random random;
            String board = DraughtsRules.startingBoard();
            Color  turn  = Black;
            Int    plies = 0;
            while (plies < 200) {
                Move move;
                if (!(move := DraughtsAi.chooseMove(board, turn, "easy", random))) {
                    break;
                }
                assert DraughtsRules.findMove(board, turn, move.path);
                (board, _) = DraughtsRules.applyMove(board, move);
                turn = DraughtsRules.opponent(turn);
                ++plies;
            }
            assert plies > 10;
        }
    }
}
