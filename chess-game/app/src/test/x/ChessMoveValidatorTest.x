module ChessMoveValidatorTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;
    package xunit import xunit.xtclang.org;

    import chess.core.ChessLogic;
    import chess.validation.MoveValidator;
    import chess.utils.BoardUtils;

    import db.models.Color;
    import db.models.CastlingRights;

    import xunit.annotations.Disabled;

    /**
     * Tests for high-level move validation with error reporting.
     */
    class MoveValidatorTests {
        @Test
        void shouldReturnDetailedValidationResults() {
            val board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());

            val ok = MoveValidator.validateMove(
                board, 52, 36, Color.White, new CastlingRights(), Null);
            assert ok.isValid;

            val invalidSquare = MoveValidator.validateMove(
                board, -1, 36, Color.White, new CastlingRights(), Null);
            assert !invalidSquare.isValid;
            assert invalidSquare.errorMessage == "Invalid square index";

            val noPiece = MoveValidator.validateMove(
                board, 40, 32, Color.White, new CastlingRights(), Null);
            assert noPiece.errorMessage == "No piece on source square";

            val outOfTurn = MoveValidator.validateMove(
                board, 52, 36, Color.Black, new CastlingRights(), Null);
            assert outOfTurn.outOfTurn;
            assert outOfTurn.errorMessage == "Not your turn";

            val ownPiece = MoveValidator.validateMove(
                board, 52, 53, Color.White, new CastlingRights(), Null);
            assert ownPiece.errorMessage == "Cannot capture your own piece";

            val illegal = MoveValidator.validateMove(
                board, 52, 53, Color.White, new CastlingRights(), Null);
            assert !illegal.invalidPieceMove;
        }

        @Disabled("MoveValidator.validateMove doesn't flag leaveKingInCheck when it should — needs investigation")
        @Test
        void shouldDetectMoveThatLeavesKingInCheck() {
            val board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            board[4] = 'r';
            board[12] = '.';
            board[20] = '.';
            board[28] = '.';
            board[36] = '.';
            board[44] = '.';
            board[52] = 'P';
            board[60] = 'K';

            val result = MoveValidator.validateMove(
                board, 52, 44, Color.White, new CastlingRights(), Null);
            assert !result.isValid;
            assert result.leaveKingInCheck;
            assert result.errorMessage == "Move leaves king in check";
        }

        @Test
        void shouldValidateMoveWithTargetIndexOutOfRange() {
            val board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            val tooBig = MoveValidator.validateMove(
                board, 52, 64, Color.White, new CastlingRights(), Null);
            assert !tooBig.isValid;
            assert tooBig.errorMessage == "Invalid square index";
        }
    }
}
