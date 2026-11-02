module ChessAIMoveSelectionTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.ai.ChessAPIClient;
    import chess.utils.BoardUtils;

    import db.models.Color;

    /**
     * Tests for the computer's move selection.
     */
    class AISelectionTests {
        @Test
        void shouldReturnALegalMoveForTheSideToMove() {
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;

            ChessAPIClient client = new ChessAPIClient();
            (Int from, Int to, String? promotion) = client.findBestMove(afterE4);
            assert from >= 0;
            assert to >= 0;
            assert BoardUtils.colorOf(afterE4.board[from]) == Color.Black;
            assert promotion == Null || promotion == "q";
        }
    }
}
