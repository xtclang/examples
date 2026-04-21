module ChessCheckDetectionTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.validation.CheckDetection;
    import chess.validation.ValidMovesHelper;
    import chess.utils.BoardUtils;

    import db.models.Color;
    import db.models.CastlingRights;
    import db.models.MoveHistoryEntry;

    /**
     * Tests for check, checkmate, stalemate and draw detection.
     */
    class CheckDetectionTests {
        @Test
        void shouldDetectCheckCheckmateAndStalemate() {
            Char[] checkBoard = new Char[64](i -> '.');
            checkBoard[7] = 'k';
            checkBoard[13] = 'K';
            checkBoard[22] = 'Q';
            assert CheckDetection.isInCheck(checkBoard.freeze(), Color.Black);

            (Boolean checkmate, Boolean stalemate) = CheckDetection.checkGameEnd(
                new String(checkBoard), Color.Black, new CastlingRights(), Null);
            assert checkmate;
            assert !stalemate;

            Char[] staleBoard = new Char[64](i -> '.');
            staleBoard[0] = 'k';
            staleBoard[17] = 'Q';
            staleBoard[18] = 'K';
            (Boolean staleMate, Boolean staleOnly) = CheckDetection.checkGameEnd(
                new String(staleBoard), Color.Black, new CastlingRights(), Null);
            assert !staleMate;
            assert staleOnly;
        }

        @Test
        void shouldDetectAttackDrawAndRepetitionRules() {
            Char[] board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            board[4] = 'r';
            board[12] = '.';
            board[20] = '.';
            board[28] = '.';
            board[36] = '.';
            board[44] = '.';
            assert CheckDetection.isSquareAttacked(60, board.freeze(), Color.Black);
            assert !CheckDetection.isMoveLegalWithCheck(board, 52, 44, Color.White);

            String loneKing = "........" +
                              "........" +
                              "........" +
                              "........" +
                              "........" +
                              "........" +
                              "........" +
                              "K....k..";
            assert CheckDetection.isInsufficientMaterial(loneKing);
            assert CheckDetection.isFiftyMoveRule(100);

            String currentBoard = ChessLogic.defaultBoard();
            MoveHistoryEntry[] history = [
                new MoveHistoryEntry(1, Color.Black, "a7", "a6", 'p', Null, Null, False, False, Null, False, "", currentBoard),
                new MoveHistoryEntry(2, Color.Black, "a6", "a5", 'p', Null, Null, False, False, Null, False, "", currentBoard)
            ];
            assert CheckDetection.isThreefoldRepetition(history, currentBoard, Color.White, new CastlingRights(), Null);
        }

        @Test
        void shouldNotFlagInsufficientMaterialWithPawnsPresent() {
            String withPawns = "....k..." +
                               "....p..." +
                               "........" +
                               "........" +
                               "........" +
                               "........" +
                               "........" +
                               "....K...";
            assert !CheckDetection.isInsufficientMaterial(withPawns);
        }

        @Test
        void shouldDetectInsufficientMaterialWithKingAndBishop() {
            String kingBishop = "....k..." +
                                "........" +
                                "..b....." +
                                "........" +
                                "........" +
                                "........" +
                                "........" +
                                "....K...";
            assert CheckDetection.isInsufficientMaterial(kingBishop);
        }

        @Test
        void shouldDetectInsufficientMaterialWithKingAndKnight() {
            String kingKnight = "....k..." +
                                "........" +
                                "..n....." +
                                "........" +
                                "........" +
                                "........" +
                                "........" +
                                "....K...";
            assert CheckDetection.isInsufficientMaterial(kingKnight);
        }

        @Test
        void shouldNotFlagFiftyMoveRuleBeforeThreshold() {
            assert !CheckDetection.isFiftyMoveRule(99);
            assert !CheckDetection.isFiftyMoveRule(0);
            assert CheckDetection.isFiftyMoveRule(100);
            assert CheckDetection.isFiftyMoveRule(150);
        }

        @Test
        void shouldGetAllLegalMovesForStartingPosition() {
            Char[] board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            (Int[] froms, Int[] tos) = CheckDetection.getAllLegalMoves(
                board, Color.White, new CastlingRights(), Null);
            assert froms.size == tos.size;
            // White has 20 legal moves in starting position (16 pawn + 4 knight)
            assert froms.size == 20;
        }

        @Test
        void shouldVerifyKingCannotMoveIntoAttackedSquare() {
            Char[] board = new Char[64](i -> '.');
            board[0] = 'k';
            board[63] = 'K';
            board[7] = 'r'; // black rook on h8
            // h1 (index 63) is attacked by rook on h8 (index 7)
            assert CheckDetection.isSquareAttacked(63, board.freeze(), Color.Black);
        }

        @Test
        void shouldVerifyMoveLegalityWithRespectToCheck() {
            Char[] board = new Char[64](i -> '.');
            board[4] = 'k';
            board[60] = 'K';
            board[52] = 'P'; // Pawn on e2
            // No check, pawn move is legal
            assert CheckDetection.isMoveLegalWithCheck(board, 52, 44, Color.White);
        }
    }

    /**
     * Tests for computing valid move lists for UI highlighting.
     */
    class ValidMovesHelperTests {
        @Test
        void shouldReturnValidMovesForStartingPawn() {
            String[] moves = ValidMovesHelper.getValidMoves(ChessLogic.defaultBoard(), "e2", Color.White);
            assert moves.size == 2;
            assert moves[0] == "e3" || moves[1] == "e3";
            assert moves[0] == "e4" || moves[1] == "e4";
        }

        @Test
        void shouldReturnEmptyWhenInputIsInvalidOrWrongColor() {
            assert ValidMovesHelper.getValidMoves(ChessLogic.defaultBoard(), "z9", Color.White).empty;
            assert ValidMovesHelper.getValidMoves(ChessLogic.defaultBoard(), "e2", Color.Black).empty;
        }

        @Test
        void shouldReturnValidMovesForKnightOnStartingPosition() {
            String[] moves = ValidMovesHelper.getValidMoves(ChessLogic.defaultBoard(), "b1", Color.White);
            assert moves.size == 2; // Na3 and Nc3
        }

        @Test
        void shouldReturnNoMovesForEmptySquare() {
            assert ValidMovesHelper.getValidMoves(ChessLogic.defaultBoard(), "e4", Color.White).empty;
        }

        @Test
        void shouldReturnMultipleMovesForCenterKnight() {
            Char[] board = new Char[64](i -> '.');
            board[4] = 'k';
            board[60] = 'K';
            board[35] = 'N'; // Knight on d4
            String[] moves = ValidMovesHelper.getValidMoves(new String(board), "d4", Color.White);
            assert moves.size > 0;
            assert moves.size <= 8;
        }
    }
}
