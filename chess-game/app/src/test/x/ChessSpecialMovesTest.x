module ChessSpecialMovesTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.core.ChessGame.MoveOutcome;
    import chess.utils.BoardUtils;

    import db.models.Color;
    import db.models.CastlingRights;
    import db.models.GameRecord;
    import db.models.GameStatus;

    /**
     * Tests for special moves: castling, en passant, promotion.
     */
    class SpecialMovesTests {
        @Test
        void shouldApplyKingsideCastling() {
            val board = BoardUtils.cloneBoard("r...k..r" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "R...K..R");
            val record = new GameRecord(
                new String(board), Color.White, GameStatus.Ongoing, Null,
                0, 0, new CastlingRights(True, True, True, True), Null, [], Null, 0);
            val castled = ChessLogic.applyMove(record, board, 60, 62, Null);
            assert castled.board[62] == 'K';
            assert castled.board[61] == 'R';
            assert castled.board[63] == '.';
            assert castled.board[60] == '.';
            assert castled.lastMove == "e1g1";
        }

        @Test
        void shouldApplyQueensideCastling() {
            val board = BoardUtils.cloneBoard("r...k..r" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "R...K..R");
            val record = new GameRecord(
                new String(board), Color.White, GameStatus.Ongoing, Null,
                0, 0, new CastlingRights(True, True, True, True), Null, [], Null, 0);
            val castled = ChessLogic.applyMove(record, board, 60, 58, Null);
            assert castled.board[58] == 'K';
            assert castled.board[59] == 'R';
            assert castled.board[56] == '.';
            assert castled.board[60] == '.';
            assert castled.lastMove == "e1c1";
        }

        @Test
        void shouldApplyPawnPromotion() {
            val board = new Char[64](i -> '.');
            board[0] = 'k';
            board[63] = 'K';
            board[8] = 'P';
            val record = new GameRecord(
                new String(board), Color.White, GameStatus.Ongoing, Null,
                0, 0, new CastlingRights(False, False, False, False), Null, [], Null, 0);
            val promoted = ChessLogic.applyMove(record, board, 8, 0, Null);
            assert promoted.board[0] == 'Q';
            assert promoted.board[8] == '.';
        }

        @Test
        void shouldApplyEnPassantCapture() {
            val board = new Char[64](i -> '.');
            board[7] = 'k';
            board[63] = 'K';
            board[28] = 'P';
            board[27] = 'p';
            val record = new GameRecord(
                new String(board), Color.White, GameStatus.Ongoing, Null,
                0, 0, new CastlingRights(False, False, False, False), "d6", [], Null, 0);
            val enPassant = ChessLogic.applyMove(record, board, 28, 19, Null);
            assert enPassant.board[19] == 'P';
            assert enPassant.board[27] == '.';
            assert enPassant.board[28] == '.';
            assert enPassant.moveHistory.size == 1;
        }

        @Test
        void shouldSetEnPassantTargetAfterDoublePawnPush() {
            val game = ChessLogic.defaultGame();
            val result = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            assert result.ok;
            assert result.record.enPassantTarget == "e3";
        }

        @Test
        void shouldClearEnPassantTargetAfterNonDoublePush() {
            val game = ChessLogic.defaultGame();
            // White plays e4 (sets en passant target)
            val e4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            assert e4.record.enPassantTarget == "e3";
            // Black plays d5 (sets new en passant target, clears old)
            val d5 = ChessLogic.applyHumanMove(e4.record, "d7", "d5", Null);
            assert d5.record.enPassantTarget == "d6";
            // White plays Nf3 (no double push, en passant should be cleared)
            val nf3 = ChessLogic.applyHumanMove(d5.record, "g1", "f3", Null);
            assert nf3.record.enPassantTarget == Null;
        }

        @Test
        void shouldRevokeCastlingRightsAfterKingMoves() {
            val board = BoardUtils.cloneBoard("r...k..r" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "........" +
                                                "R...K..R");
            val record = new GameRecord(
                new String(board), Color.White, GameStatus.Ongoing, Null,
                0, 0, new CastlingRights(True, True, True, True), Null, [], Null, 0);
            // Move white king one square (not castling)
            val moved = ChessLogic.applyMove(record, board, 60, 61, Null);
            assert !moved.castlingRights.whiteKingside;
            assert !moved.castlingRights.whiteQueenside;
            // Black castling rights should remain
            assert moved.castlingRights.blackKingside;
            assert moved.castlingRights.blackQueenside;
        }
    }
}
