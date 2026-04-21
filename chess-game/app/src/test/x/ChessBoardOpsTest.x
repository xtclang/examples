module ChessBoardOpsTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.utils.BoardUtils;
    import chess.utils.BoardOperations;
    import chess.config.CastlingManager;
    import chess.config.MoveContext;

    import db.models.Color;
    import db.models.CastlingRights;

    /**
     * Tests for board-level operations: find, count, move, material.
     */
    class BoardOperationsTests {
        @Test
        void shouldFindAndCountPieces() {
            String board = "rnbqkbnr" +
                           "pppppppp" +
                           "........" +
                           "........" +
                           "........" +
                           "........" +
                           "PPPPPPPP" +
                           "RNBQKBNR";
            Char[] array = BoardUtils.cloneBoard(board);
            assert BoardOperations.findPiece(array, 'K') == 60;
            assert BoardOperations.countPieces(array, Color.White) == 16;
            assert BoardOperations.countPieces(array, Color.Black) == 16;
            assert BoardOperations.getOccupiedSquares(array, Color.White).size == 16;
            assert BoardOperations.getEmptySquares(array).size == 32;
        }

        @Test
        void shouldApplyAndCopyMoves() {
            Char[] board = BoardUtils.cloneBoard("rnbqkbnr" +
                                                "pppppppp" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "PPPPPPPP" +
                                                "RNBQKBNR");
            BoardOperations.applyMove(board, 52, 36);
            assert board[52] == '.';
            assert board[36] == 'P';

            Char[] copied = BoardOperations.boardWithMove(board, 12, 28);
            assert copied[12] == '.';
            assert copied[28] == 'p';
            assert board[12] == 'p';
        }

        @Test
        void shouldMeasureMaterialAndBoardIntegrity() {
            Char[] board = BoardUtils.cloneBoard("rnbqkbnr" +
                                                "pppppppp" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "PPPPPPPP" +
                                                "RNBQKBNR");
            assert BoardOperations.calculateMaterialBalance(board) == 0;
            assert BoardOperations.isValidBoard(board);
            assert BoardOperations.isCapture(board, 52, 36) == False;
            assert BoardOperations.areAdjacent(0, 1);
        }

        @Test
        void shouldDetectCaptures() {
            Char[] board = new Char[64](i -> '.');
            board[0] = 'k';
            board[63] = 'K';
            board[35] = 'P';
            board[26] = 'p';
            assert BoardOperations.isCapture(board, 35, 26);
            assert !BoardOperations.isCapture(board, 35, 27);
        }

        @Test
        void shouldFindMultiplePieces() {
            String board = "rnbqkbnr" +
                           "pppppppp" +
                           "........" +
                           "........" +
                           "........" +
                           "........" +
                           "PPPPPPPP" +
                           "RNBQKBNR";
            Char[] array = BoardUtils.cloneBoard(board);
            Int[] pawns = BoardOperations.findPieces(array, 'P', Color.White);
            assert pawns.size == 8;
            Int[] knights = BoardOperations.findPieces(array, 'N', Color.White);
            assert knights.size == 2;
        }

        @Test
        void shouldDetectEmptyAndOccupiedSquares() {
            Char[] board = BoardUtils.cloneBoard("rnbqkbnr" +
                                                "pppppppp" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "PPPPPPPP" +
                                                "RNBQKBNR");
            assert BoardOperations.isEmpty(board, 32); // a4, empty
            assert !BoardOperations.isEmpty(board, 0);  // a8, has rook
            assert BoardOperations.isOccupiedBy(board, 0, Color.Black);
            assert BoardOperations.isOccupiedBy(board, 56, Color.White);
            assert !BoardOperations.isOccupiedBy(board, 32, Color.White);
        }

        @Test
        void shouldReportMaterialBalanceWithMissingPieces() {
            Char[] board = new Char[64](i -> '.');
            board[0] = 'k';
            board[63] = 'K';
            board[60] = 'Q'; // White queen worth 9
            Int balance = BoardOperations.calculateMaterialBalance(board);
            assert balance > 0; // White has more material
        }

        @Test
        void shouldDetectAdjacentSquares() {
            assert BoardOperations.areAdjacent(0, 1);   // Same rank
            assert BoardOperations.areAdjacent(0, 8);   // Same file
            assert BoardOperations.areAdjacent(0, 9);   // Diagonal
            assert !BoardOperations.areAdjacent(0, 16);  // Two ranks apart
            assert !BoardOperations.areAdjacent(0, 2);   // Two files apart
        }
    }

    /**
     * Tests for castling rights management and move context.
     */
    class CastlingAndContextTests {
        @Test
        void shouldUpdateCastlingRightsAndFormatFEN() {
            CastlingRights rights = CastlingManager.defaultRights();
            assert CastlingManager.toFEN(rights) == "KQkq";
            assert CastlingManager.toFEN(CastlingManager.noRights()) == "-";

            CastlingRights afterWhiteKingMove = CastlingManager.updateRights(rights, 'K', 60, 62);
            assert !afterWhiteKingMove.whiteKingside;
            assert !afterWhiteKingMove.whiteQueenside;
            assert afterWhiteKingMove.blackKingside;
            assert afterWhiteKingMove.blackQueenside;

            CastlingRights afterRookCapture = CastlingManager.updateRights(rights, 'P', 48, 63);
            assert !afterRookCapture.whiteKingside;
        }

        @Test
        void shouldRespectMoveContextCastleChecks() {
            MoveContext noRights = new MoveContext();
            assert !noRights.canCastle(Color.White, True);

            MoveContext whiteRights = new MoveContext(new CastlingRights(True, False, False, False));
            assert whiteRights.canCastle(Color.White, True);
            assert !whiteRights.canCastle(Color.White, False);
        }

        @Test
        void shouldUpdateRightsWhenRookMoves() {
            CastlingRights rights = CastlingManager.defaultRights();
            // White kingside rook moves from h1 (index 63)
            CastlingRights afterKingsideRookMove = CastlingManager.updateRights(rights, 'R', 63, 55);
            assert !afterKingsideRookMove.whiteKingside;
            assert afterKingsideRookMove.whiteQueenside;

            // White queenside rook moves from a1 (index 56)
            CastlingRights afterQueensideRookMove = CastlingManager.updateRights(rights, 'R', 56, 48);
            assert afterQueensideRookMove.whiteKingside;
            assert !afterQueensideRookMove.whiteQueenside;
        }

        @Test
        void shouldUpdateRightsForBlackKingMove() {
            CastlingRights rights = CastlingManager.defaultRights();
            CastlingRights afterBlackKingMove = CastlingManager.updateRights(rights, 'k', 4, 5);
            assert afterBlackKingMove.whiteKingside;
            assert afterBlackKingMove.whiteQueenside;
            assert !afterBlackKingMove.blackKingside;
            assert !afterBlackKingMove.blackQueenside;
        }

        @Test
        void shouldCheckCanCastleForBothColors() {
            CastlingRights full = CastlingManager.defaultRights();
            assert CastlingManager.canCastle(full, Color.White, True);
            assert CastlingManager.canCastle(full, Color.White, False);
            assert CastlingManager.canCastle(full, Color.Black, True);
            assert CastlingManager.canCastle(full, Color.Black, False);

            CastlingRights none = CastlingManager.noRights();
            assert !CastlingManager.canCastle(none, Color.White, True);
            assert !CastlingManager.canCastle(none, Color.White, False);
            assert !CastlingManager.canCastle(none, Color.Black, True);
            assert !CastlingManager.canCastle(none, Color.Black, False);
        }

        @Test
        void shouldCreateMoveContextWithEnPassant() {
            MoveContext ctx = new MoveContext(new CastlingRights(), "e3");
            assert ctx.enPassantTarget == "e3";
        }
    }
}
