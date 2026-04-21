module ChessAIEvaluatorTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.ai.AIPositionEvaluator;
    import chess.utils.BoardUtils;

    import db.models.Color;
    import db.models.CastlingRights;
    import db.models.GameRecord;
    import db.models.GameStatus;

    /**
     * Tests for position evaluation: material values, endgame detection, passed pawns.
     */
    class AIPositionEvaluatorTests {
        @Test
        void shouldEvaluateMaterialAndEndgameHelpers() {
            Char[] board = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            assert AIPositionEvaluator.getPieceValue('p') == 100;
            assert AIPositionEvaluator.getPieceValue('q') == 900;
            assert AIPositionEvaluator.getPieceValue('k') == 20000;
            assert AIPositionEvaluator.chebyshevDistance(0, 63) == 7;
            assert AIPositionEvaluator.evaluateBoard(board, ChessLogic.defaultGame()) == 0;

            Char[] endgame = new Char[64](i -> '.');
            endgame[0] = 'k';
            endgame[63] = 'K';
            assert AIPositionEvaluator.isEndgame(endgame);
            assert AIPositionEvaluator.isPassedPawn(endgame, 48, 'P');
        }

        @Test
        void shouldReturnCorrectPieceValues() {
            assert AIPositionEvaluator.getPieceValue('p') == 100;
            assert AIPositionEvaluator.getPieceValue('n') == 320;
            assert AIPositionEvaluator.getPieceValue('b') == 330;
            assert AIPositionEvaluator.getPieceValue('r') == 500;
            assert AIPositionEvaluator.getPieceValue('q') == 900;
            assert AIPositionEvaluator.getPieceValue('k') == 20000;
        }

        @Test
        void shouldCalculateChebyshevDistanceCorrectly() {
            assert AIPositionEvaluator.chebyshevDistance(0, 0) == 0;
            assert AIPositionEvaluator.chebyshevDistance(0, 1) == 1;
            assert AIPositionEvaluator.chebyshevDistance(0, 8) == 1;
            assert AIPositionEvaluator.chebyshevDistance(0, 9) == 1;
            assert AIPositionEvaluator.chebyshevDistance(0, 63) == 7;
        }

        @Test
        void shouldDetectEndgameWithFewPieces() {
            // Endgame: only kings
            Char[] kingsOnly = new Char[64](i -> '.');
            kingsOnly[0] = 'k';
            kingsOnly[63] = 'K';
            assert AIPositionEvaluator.isEndgame(kingsOnly);

            // Not endgame: starting position
            Char[] full = BoardUtils.cloneBoard(ChessLogic.defaultBoard());
            assert !AIPositionEvaluator.isEndgame(full);
        }

        @Test
        void shouldEvaluatePositionWithMaterialAdvantage() {
            // Board where white has an extra queen
            Char[] board = new Char[64](i -> '.');
            board[0] = 'k';
            board[63] = 'K';
            board[35] = 'Q'; // White queen
            GameRecord record = new GameRecord(
                new String(board), Color.White, GameStatus.Ongoing, Null,
                0, 0, new CastlingRights(False, False, False, False), Null, [], Null, 0);
            Int eval = AIPositionEvaluator.evaluateBoard(board, record);
            assert eval > 0; // White should have positive evaluation
        }
    }
}
