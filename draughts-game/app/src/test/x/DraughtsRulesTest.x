module DraughtsRulesTest {
    package draughts import draughts.examples.org;
    package db       import draughtsDB.examples.org;

    import draughts.core.DraughtsRules;
    import draughts.core.DraughtsRules.Move;

    import db.models.Color;
    import db.models.GameStatus;

    /**
     * Builds a board from 8 row strings, the top row first.
     */
    static String board(String r0, String r1, String r2, String r3,
                        String r4, String r5, String r6, String r7) {
        return r0 + r1 + r2 + r3 + r4 + r5 + r6 + r7;
    }

    static String EMPTY = "........";

    /**
     * Square names, parsing and the starting position.
     */
    class BoardTests {
        @Test
        void shouldNameSquaresLikeChess() {
            assert DraughtsRules.parseSquare("a8") == 0;
            assert DraughtsRules.parseSquare("h1") == 63;
            assert DraughtsRules.parseSquare("c3") == 42;
            assert DraughtsRules.parseSquare("i3") == -1;
            assert DraughtsRules.parseSquare("c9") == -1;
            assert DraughtsRules.parseSquare("c") == -1;
            assert DraughtsRules.toAlgebraic(0) == "a8";
            assert DraughtsRules.toAlgebraic(63) == "h1";
            assert DraughtsRules.toAlgebraic(42) == "c3";
        }

        @Test
        void shouldParsePaths() {
            assert DraughtsRules.parsePath("c3-d4") == [42, 35];
            assert DraughtsRules.parsePath("b6-d8-f6") == [17, 3, 21];
            assert DraughtsRules.parsePath("c3-zz").empty;
            assert DraughtsRules.parsePath("").empty;
        }

        @Test
        void shouldStartWithTwelveMenEachOnDarkSquares() {
            String start = DraughtsRules.startingBoard();
            assert start.size == 64;
            assert DraughtsRules.countPieces(start, Black) == 12;
            assert DraughtsRules.countPieces(start, White) == 12;
            // White on the top three rows, Black on the bottom three, dark squares only
            assert start[0 ..< 8]   == ".w.w.w.w";
            assert start[8 ..< 16]  == "w.w.w.w.";
            assert start[16 ..< 24] == ".w.w.w.w";
            assert start[24 ..< 40] == "................";
            assert start[40 ..< 48] == "b.b.b.b.";
            assert start[48 ..< 56] == ".b.b.b.b";
            assert start[56 ..< 64] == "b.b.b.b.";
        }
    }

    /**
     * Ordinary moves.
     */
    class StepTests {
        @Test
        void shouldGiveBlackSevenOpeningMoves() {
            Move[] moves = DraughtsRules.legalMoves(DraughtsRules.startingBoard(), Black);
            assert moves.size == 7;
            assert moves.all(m -> m.captures.empty && m.path.size == 2);
        }

        @Test
        void shouldGiveWhiteSevenMovesToo() {
            assert DraughtsRules.legalMoves(DraughtsRules.startingBoard(), White).size == 7;
        }

        @Test
        void shouldMoveMenOnlyForwards() {
            // A lone Black man (moves up) and a lone White man (moves down)
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, "...b....", EMPTY, EMPTY, EMPTY);
            Move[] black = DraughtsRules.legalMoves(b, Black);
            assert black.size == 2;
            assert black.all(m -> m.path[1] / 8 == 3);

            String w = board(EMPTY, EMPTY, EMPTY, "..w.....", EMPTY, EMPTY, EMPTY, EMPTY);
            Move[] white = DraughtsRules.legalMoves(w, White);
            assert white.size == 2;
            assert white.all(m -> m.path[1] / 8 == 4);
        }

        @Test
        void shouldMoveKingsBothWays() {
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, "...B....", EMPTY, EMPTY, EMPTY);
            assert DraughtsRules.legalMoves(b, Black).size == 4;
        }

        @Test
        void shouldStayOnTheBoard() {
            // A man in the corner of its own back row has only one way to go
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, "b.......");
            assert DraughtsRules.legalMoves(b, Black).size == 1;
        }

        @Test
        void shouldApplyAStepWithoutChangingTheOldBoard() {
            String start = DraughtsRules.startingBoard();
            assert Move move := DraughtsRules.findMove(start, Black, [42, 35]);
            (String after, Boolean crowned) = DraughtsRules.applyMove(start, move);
            assert !crowned;
            assert after[42] == '.';
            assert after[35] == 'b';
            assert start[42] == 'b';
            assert start[35] == '.';
        }
    }

    /**
     * Captures: compulsory, multiple, and crowning.
     */
    class CaptureTests {
        @Test
        void shouldMakeCapturesCompulsory() {
            // Black at (4,3) can jump White at (3,2); Black at (6,1) could merely step.
            String b = board(EMPTY, EMPTY, EMPTY, "..w.....", "...b....", EMPTY, ".b......", EMPTY);
            Move[] moves = DraughtsRules.legalMoves(b, Black);
            assert moves.size == 1;
            assert moves[0].captures == [26];
            assert moves[0].path == [35, 17];
        }

        @Test
        void shouldFollowAMultipleJumpToTheEnd() {
            // Black at (6,1) jumps (5,2) to (4,3), then (3,2) to (2,1).
            String b = board(EMPTY, EMPTY, EMPTY, "..w.....", EMPTY, "..w.....", ".b......", EMPTY);
            // Only the full chain is a legal move, not the first jump on its own.
            Move[] moves = DraughtsRules.legalMoves(b, Black);
            assert moves.size == 1;
            assert moves[0].path == [49, 35, 17];
            assert moves[0].captures == [42, 26];
            assert moves[0].notation == "b2xd4xb6";
            assert !DraughtsRules.findMove(b, Black, [49, 35]);

            (String after, _) = DraughtsRules.applyMove(b, moves[0]);
            assert DraughtsRules.countPieces(after, White) == 0;
            assert after[17] == 'b';
        }

        @Test
        void shouldOfferEveryBranchOfAJumpingChoice() {
            // From (4,3) Black can jump left over (3,2) or right over (3,4).
            String b = board(EMPTY, EMPTY, EMPTY, "..w.w...", "...b....", EMPTY, EMPTY, EMPTY);
            assert DraughtsRules.legalMoves(b, Black).size == 2;
        }

        @Test
        void shouldNotJumpTwoPiecesInARow() {
            // Black at (4,3) is hemmed in by White men with a second White man behind each
            String b = board(EMPTY, EMPTY, ".w...w..", "..w.w...", "...b....", EMPTY, EMPTY, EMPTY);
            assert DraughtsRules.legalMoves(b, Black).empty;
        }

        @Test
        void shouldCrownAManReachingTheFarRow() {
            // Black at (1,2) steps onto the far row (the White man is just somewhere else)
            String b = board(EMPTY, "..b.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, "w.......");
            assert Move move := DraughtsRules.findMove(b, Black, [10, 3]);
            (String after, Boolean crowned) = DraughtsRules.applyMove(b, move);
            assert crowned;
            assert after[3] == 'B';
        }

        @Test
        void shouldEndTheMoveWhenAManIsCrownedMidJump() {
            // Black at (2,1) jumps (1,2) onto the far row and is crowned. A White man at (1,4)
            // could then be jumped backwards by the new king -- but crowning ends the move.
            String b = board(EMPTY, "..w.w...", ".b......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY);
            Move[] moves = DraughtsRules.legalMoves(b, Black);
            assert moves.size == 1;
            assert moves[0].path == [17, 3];
            assert moves[0].captures == [10];
            (String after, Boolean crowned) = DraughtsRules.applyMove(b, moves[0]);
            assert crowned;
            assert after[3] == 'B';
        }

        @Test
        void shouldLetAKingJumpBackwards() {
            // A Black king at (4,3) jumps up over (3,4), then back down over (3,6).
            String b = board(EMPTY, EMPTY, EMPTY, "....w.w.", "...B....", EMPTY, EMPTY, EMPTY);
            Move[] moves = DraughtsRules.legalMoves(b, Black);
            assert moves.size == 1;
            assert moves[0].path == [35, 21, 39];
            assert moves[0].captures == [28, 30];

            // A man in the same place could jump only the first piece
            String man = board(EMPTY, EMPTY, EMPTY, "....w.w.", "...b....", EMPTY, EMPTY, EMPTY);
            assert DraughtsRules.legalMoves(man, Black)[0].captures == [28];
        }

        @Test
        void shouldNotCrownAKingAgain() {
            // A king already on the far row moves off it and stays a king
            String b = board("...B....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY);
            assert Move move := DraughtsRules.findMove(b, Black, [3, 10]);
            (String after, Boolean crowned) = DraughtsRules.applyMove(b, move);
            assert !crowned;
            assert after[10] == 'B';
        }
    }

    /**
     * How a game ends.
     */
    class ResultTests {
        @Test
        void shouldBeOngoingAtTheStart() {
            assert DraughtsRules.statusOf(DraughtsRules.startingBoard(), Black, 0) == Ongoing;
        }

        @Test
        void shouldLoseWithNoPiecesLeft() {
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, "...b....", EMPTY, EMPTY, EMPTY);
            assert DraughtsRules.statusOf(b, White, 0) == BlackWins;

            String w = board(EMPTY, EMPTY, EMPTY, "..w.....", EMPTY, EMPTY, EMPTY, EMPTY);
            assert DraughtsRules.statusOf(w, Black, 0) == WhiteWins;
        }

        @Test
        void shouldLoseWhenEveryPieceIsBlocked() {
            // A White man at (7,0) has nowhere to go: it is on the far row and men move forward.
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, "w.......");
            assert DraughtsRules.statusOf(b, White, 0) == BlackWins;
        }

        @Test
        void shouldDrawAfterFortyQuietMovesEach() {
            String b = board(EMPTY, EMPTY, EMPTY, EMPTY, "...B....", EMPTY, EMPTY, "......W.");
            assert DraughtsRules.statusOf(b, Black, 79) == Ongoing;
            assert DraughtsRules.statusOf(b, Black, 80) == Draw;
        }
    }
}
