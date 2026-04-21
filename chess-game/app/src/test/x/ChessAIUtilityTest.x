module ChessAIUtilityTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.ai.AIUtility;
    import chess.utils.BoardUtils;

    import db.models.Color;
    import db.models.GameRecord;

    /**
     * Tests for AI utility functions: hashing, FEN generation, random move finding.
     */
    class AIUtilityTests {
        @Test
        void shouldHashDeterministicallyAndFormatFen() {
            assert AIUtility.hashRandom(123, 456) == AIUtility.hashRandom(123, 456);
            assert AIUtility.hashRandom(123, 456) != AIUtility.hashRandom(123, 457);
            assert AIUtility.hashRandom(123, 456) >= 0;

            GameRecord record = ChessLogic.defaultGame();
            assert AIUtility.boardToFen(record) == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
        }

        @Test
        void shouldFindRandomLegalMoveOnAPlayablePosition() {
            GameRecord afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            (Int from, Int to, String? promo) = AIUtility.findRandomLegalMove(afterE4);
            assert from >= 0;
            assert to >= 0;
            assert promo == Null;
            assert BoardUtils.colorOf(afterE4.board[from]) == Color.Black;
        }

        @Test
        void shouldProduceDifferentHashesForDifferentInputs() {
            Int hash1 = AIUtility.hashRandom(100, 200);
            Int hash2 = AIUtility.hashRandom(100, 201);
            Int hash3 = AIUtility.hashRandom(101, 200);
            assert hash1 != hash2;
            assert hash1 != hash3;
            assert hash2 != hash3;
        }

        @Test
        void shouldGenerateFenWithCorrectTurnAndCastling() {
            GameRecord game = ChessLogic.defaultGame();
            String fen = AIUtility.boardToFen(game);
            // Should contain White's turn
            assert fen.indexOf(" w ");
            // Should contain full castling rights
            assert fen.indexOf("KQkq");

            // After a move, turn should switch
            GameRecord afterE4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null).record;
            String fenAfterE4 = AIUtility.boardToFen(afterE4);
            assert fenAfterE4.indexOf(" b ");
        }

        @Test
        void shouldFindRandomMoveFromMultiplePositions() {
            GameRecord game = ChessLogic.defaultGame();
            // After 1. e4 e5 2. Nf3, Black has many legal moves
            GameRecord afterE4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null).record;
            GameRecord afterE5 = ChessLogic.applyHumanMove(afterE4, "e7", "e5", Null).record;
            GameRecord afterNf3 = ChessLogic.applyHumanMove(afterE5, "g1", "f3", Null).record;
            (Int from, Int to, String? promo) = AIUtility.findRandomLegalMove(afterNf3);
            assert from >= 0;
            assert to >= 0;
            assert BoardUtils.colorOf(afterNf3.board[from]) == Color.Black;
        }
    }
}
