module ChessBoardUtilsTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.utils.BoardUtils;
    import chess.utils.DirectionUtils;

    import db.models.Color;

    /**
     * Tests for board coordinate parsing, formatting, cloning and piece color detection.
     */
    class BoardAndDirectionTests {
        @Test
        void shouldParseAndFormatSquares() {
            assert BoardUtils.parseSquare("a8") == 0;
            assert BoardUtils.parseSquare("e4") == 36;
            assert BoardUtils.parseSquare("h1") == 63;
            assert BoardUtils.toAlgebraic(0) == "a8";
            assert BoardUtils.toAlgebraic(36) == "e4";
            assert BoardUtils.toAlgebraic(63) == "h1";
        }

        @Test
        void shouldRejectInvalidSquares() {
            assert BoardUtils.parseSquare("e9") == BoardUtils.INVALID_SQUARE;
            assert BoardUtils.parseSquare("z1") == BoardUtils.INVALID_SQUARE;
            assert BoardUtils.parseSquare("a") == BoardUtils.INVALID_SQUARE;
        }

        @Test
        void shouldCloneAndSplitBoardRows() {
            String board = "rnbqkbnr" +
                           "pppppppp" +
                           "........" +
                           "........" +
                           "........" +
                           "........" +
                           "PPPPPPPP" +
                           "RNBQKBNR";
            Char[] clone = BoardUtils.cloneBoard(board);
            clone[0] = '.';
            assert board[0] == 'r';
            assert BoardUtils.boardRows(board)[0] == "rnbqkbnr";
            assert BoardUtils.boardRows(board)[7] == "RNBQKBNR";
        }

        @Test
        void shouldDetectPieceColorAndDistance() {
            assert BoardUtils.colorOf('p') == Color.Black;
            assert BoardUtils.colorOf('P') == Color.White;
            assert BoardUtils.isValidSquare(0);
            assert !BoardUtils.isValidSquare(64);
            assert BoardUtils.getDistance(0, 9) == 1;
            assert BoardUtils.getDistance(0, 63) == 7;
        }

        @Test
        void shouldFindStraightAndDiagonalDirections() {
            assert DirectionUtils.calculateStep(0, 7) == DirectionUtils.EAST;
            assert DirectionUtils.calculateStep(0, 56) == DirectionUtils.SOUTH;
            assert DirectionUtils.calculateStep(0, 9) == DirectionUtils.SOUTHEAST;
            assert DirectionUtils.calculateStep(63, 54) == DirectionUtils.NORTHWEST;
            assert DirectionUtils.isSameFile(0, 56);
            assert DirectionUtils.isSameRank(0, 7);
            assert DirectionUtils.isSameDiagonal(0, 9);
            assert DirectionUtils.isStraightLine(0, 56);
        }

        @Test
        void shouldCheckRayAndPathBlocking() {
            Char[] board = BoardUtils.cloneBoard("rnbqkbnr" +
                                                "pppppppp" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "PPPPPPPP" +
                                                "RNBQKBNR");
            assert !DirectionUtils.isPathClear(0, 56, board);
            board[8] = '.';
            board[16] = '.';
            board[24] = '.';
            board[32] = '.';
            board[40] = '.';
            board[48] = '.';
            assert DirectionUtils.isPathClear(0, 56, board);

            Int[] ray = DirectionUtils.getRaySquares(0, DirectionUtils.SOUTH, 3);
            assert ray.size == 3;
            assert ray[0] == 8;
            assert ray[2] == 24;
        }

        @Test
        void shouldParseAllCornerSquares() {
            assert BoardUtils.parseSquare("a8") == 0;
            assert BoardUtils.parseSquare("h8") == 7;
            assert BoardUtils.parseSquare("a1") == 56;
            assert BoardUtils.parseSquare("h1") == 63;
        }

        @Test
        void shouldFormatAllCornerSquares() {
            assert BoardUtils.toAlgebraic(0) == "a8";
            assert BoardUtils.toAlgebraic(7) == "h8";
            assert BoardUtils.toAlgebraic(56) == "a1";
            assert BoardUtils.toAlgebraic(63) == "h1";
        }

        @Test
        void shouldReportFileAndRank() {
            assert BoardUtils.getFile(0) == 0;  // a-file
            assert BoardUtils.getFile(7) == 7;  // h-file
            assert BoardUtils.getRank(0) == 0;  // 8th rank
            assert BoardUtils.getRank(63) == 7; // 1st rank
            assert BoardUtils.getFile(36) == 4; // e-file
            assert BoardUtils.getRank(36) == 4; // 4th rank
        }

        @Test
        void shouldValidateSquareBoundaries() {
            assert BoardUtils.isValidSquare(0);
            assert BoardUtils.isValidSquare(63);
            assert !BoardUtils.isValidSquare(-1);
            assert !BoardUtils.isValidSquare(64);
            assert !BoardUtils.isValidSquare(100);
        }

        @Test
        void shouldCalculateDistanceBetweenSquares() {
            assert BoardUtils.getDistance(0, 0) == 0;
            assert BoardUtils.getDistance(0, 1) == 1;  // Adjacent same rank
            assert BoardUtils.getDistance(0, 8) == 1;  // Adjacent same file
            assert BoardUtils.getDistance(0, 9) == 1;  // Adjacent diagonal
            assert BoardUtils.getDistance(0, 63) == 7; // Max distance corner to corner
        }

        @Test
        void shouldDetectDiagonalVsStraightRelationships() {
            // Same file
            assert DirectionUtils.isSameFile(0, 8);
            assert DirectionUtils.isSameFile(0, 56);
            assert !DirectionUtils.isSameFile(0, 1);
            // Same rank
            assert DirectionUtils.isSameRank(0, 1);
            assert DirectionUtils.isSameRank(0, 7);
            assert !DirectionUtils.isSameRank(0, 8);
            // Same diagonal
            assert DirectionUtils.isSameDiagonal(0, 9);
            assert DirectionUtils.isSameDiagonal(0, 63);
            assert !DirectionUtils.isSameDiagonal(0, 1);
            // Straight line (file or rank)
            assert DirectionUtils.isStraightLine(0, 7);
            assert DirectionUtils.isStraightLine(0, 56);
            assert !DirectionUtils.isStraightLine(0, 9);
        }

        @Test
        void shouldCalculateStepInAllDirections() {
            // North
            assert DirectionUtils.calculateStep(8, 0) == DirectionUtils.NORTH;
            // South
            assert DirectionUtils.calculateStep(0, 8) == DirectionUtils.SOUTH;
            // East
            assert DirectionUtils.calculateStep(0, 1) == DirectionUtils.EAST;
            // West
            assert DirectionUtils.calculateStep(1, 0) == DirectionUtils.WEST;
            // Diagonals
            assert DirectionUtils.calculateStep(9, 0) == DirectionUtils.NORTHWEST;
            assert DirectionUtils.calculateStep(0, 9) == DirectionUtils.SOUTHEAST;
        }
    }
}
