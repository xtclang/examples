module ChessBoardOpsTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.utils.BoardUtils;
    import chess.utils.BoardOperations;
    import chess.config.CastlingManager;

    import db.models.CastlingRights;

    /**
     * Tests for board-level operations: find, move, capture.
     */
    class BoardOperationsTests {
        @Test
        void shouldFindPieces() {
            val array = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            assert BoardOperations.findPiece(array, 'K') == 60;
            assert BoardOperations.findPiece(array, 'k') == 4;
        }

        @Test
        void shouldApplyAndCopyMoves() {
            val board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            BoardOperations.applyMove(board, 52, 36);
            assert board[52] == '.';
            assert board[36] == 'P';

            val copied = BoardOperations.boardWithMove(board, 12, 28);
            assert copied[12] == '.';
            assert copied[28] == 'p';
            assert board[12] == 'p';
        }

        @Test
        void shouldNotTreatAMoveToAnEmptySquareAsACapture() {
            val board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            assert BoardOperations.isCapture(board, 52, 36) == False;
        }

        @Test
        void shouldDetectCaptures() {
            val board = new Char[64](i -> '.');
            board[0] = 'k';
            board[63] = 'K';
            board[35] = 'P';
            board[26] = 'p';
            assert BoardOperations.isCapture(board, 35, 26);
            assert !BoardOperations.isCapture(board, 35, 27);
        }
    }

    /**
     * Tests for castling rights management.
     */
    class CastlingAndContextTests {
        @Test
        void shouldUpdateCastlingRightsAndFormatFEN() {
            val rights = new CastlingRights();

            val afterWhiteKingMove = CastlingManager.updateRights(rights, 'K', 60, 62);
            assert !afterWhiteKingMove.whiteKingside;
            assert !afterWhiteKingMove.whiteQueenside;
            assert afterWhiteKingMove.blackKingside;
            assert afterWhiteKingMove.blackQueenside;

            val afterRookCapture = CastlingManager.updateRights(rights, 'P', 48, 63);
            assert !afterRookCapture.whiteKingside;
        }

        @Test
        void shouldUpdateRightsWhenRookMoves() {
            val rights = new CastlingRights();
            // White kingside rook moves from h1 (index 63)
            val afterKingsideRookMove = CastlingManager.updateRights(rights, 'R', 63, 55);
            assert !afterKingsideRookMove.whiteKingside;
            assert afterKingsideRookMove.whiteQueenside;

            // White queenside rook moves from a1 (index 56)
            val afterQueensideRookMove = CastlingManager.updateRights(rights, 'R', 56, 48);
            assert afterQueensideRookMove.whiteKingside;
            assert !afterQueensideRookMove.whiteQueenside;
        }

        @Test
        void shouldUpdateRightsForBlackKingMove() {
            val rights = new CastlingRights();
            val afterBlackKingMove = CastlingManager.updateRights(rights, 'k', 4, 5);
            assert afterBlackKingMove.whiteKingside;
            assert afterBlackKingMove.whiteQueenside;
            assert !afterBlackKingMove.blackKingside;
            assert !afterBlackKingMove.blackQueenside;
        }
    }
}
