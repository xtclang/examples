module ChessAIMoveSelectionTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.ai.ChessAPIClient;
    import chess.ai.AIOpeningBook;
    import chess.ai.AIPositionEvaluator;
    import chess.ai.AIMoveSelector;
    import chess.ai.AISearchEngine;
    import chess.ai.ChessAI;
    import chess.utils.BoardUtils;

    import db.models.Color;
    import db.models.GameRecord;

    /**
     * Tests for move selection, opening book, and search engine.
     */
    class AISelectionTests {
        @Test
        void shouldPreferOpeningAndLegalCandidates() {
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            (Int openFrom, Int openTo) = AIOpeningBook.getOpeningMove(afterE4);
            assert openFrom >= 0;
            assert openTo >= 0;
            assert BoardUtils.colorOf(afterE4.board[openFrom]) == Color.Black;

            ChessAPIClient client = new ChessAPIClient();
            (Int from, Int to, String? promotion) = client.findBestMove(afterE4);
            assert from >= 0;
            assert to >= 0;
            assert BoardUtils.colorOf(afterE4.board[from]) == Color.Black;
            assert promotion == Null || promotion == "q";

            (Int[] orderedFroms, Int[] orderedTos, Int[] scores) = AIMoveSelector.collectOrderedLegalMoves(afterE4, BoardUtils.cloneBoard(afterE4.board));
            assert orderedFroms.size == orderedTos.size;
            assert orderedFroms.size == scores.size;
            assert orderedFroms.size > 0;

            val eval = AISearchEngine.minimax(BoardUtils.cloneBoard(afterE4.board), afterE4, 0, -1000000, 1000000, True);
            assert eval == AIPositionEvaluator.evaluateBoard(BoardUtils.cloneBoard(afterE4.board), afterE4);
        }

        @Test
        void shouldExposeLegacyFacadeHelpers() {
            val game = ChessLogic.defaultGame();
            assert ChessAI.isOpeningPhase(game);
            assert ChessAI.totalMaterial(BoardUtils.cloneBoard(game.board)) == 8000;
            assert ChessAI.randomInt(10, 5, 2) >= 0;

            (Int from, Int to, Int score) = ChessAI.findBestMove(game);
            assert from >= -1;
            assert to >= -1;
            assert score <= ChessAI.MAX_SCORE;
        }

        @Test
        void shouldCollectNonZeroLegalMovesFromStartingPosition() {
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            (Int[] froms, Int[] tos, Int[] scores) = AIMoveSelector.collectOrderedLegalMoves(afterE4, BoardUtils.cloneBoard(afterE4.board));
            // Black should have 20 legal moves in response to 1. e4
            assert froms.size == 20;
            // Scores should be ordered (move ordering)
            for (Int i : 0 ..< scores.size - 1) {
                assert scores[i] >= scores[i + 1];
            }
        }

        @Test
        void shouldReturnOpeningMoveForBlack() {
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            (Int from, Int to) = AIOpeningBook.getOpeningMove(afterE4);
            // Opening book should return a valid Black piece
            assert from >= 0 && from < 64;
            assert to >= 0 && to < 64;
            Char piece = afterE4.board[from];
            assert piece >= 'a' && piece <= 'z'; // Black piece (lowercase)
        }

        @Test
        void shouldEvaluateToZeroAtDepthZero() {
            val game = ChessLogic.defaultGame();
            val board = BoardUtils.cloneBoard(game.board);
            // At depth 0, minimax should return static evaluation
            val eval = AISearchEngine.minimax(board, game, 0, -1000000, 1000000, True);
            val staticEval = AIPositionEvaluator.evaluateBoard(board, game);
            assert eval == staticEval;
        }
    }
}
