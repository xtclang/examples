module ChessGamePlayTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.core.ChessGame.MoveOutcome;
    import chess.core.ChessGame.AutoResponse;

    import db.models.Color;
    import db.models.CastlingRights;
    import db.models.GameRecord;
    import db.models.GameStatus;
    import db.models.MoveHistoryEntry;

    /**
     * Tests for game flow: multiple move sequences, checkmate, stalemate, draws.
     */
    class GameFlowTests {
        @Test
        void shouldReachScholarsMate() {
            // Scholar's mate: 1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6?? 4. Qxf7#
            val game = ChessLogic.defaultGame();
            val e4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            assert e4.ok;
            val e5 = ChessLogic.applyHumanMove(e4.record, "e7", "e5", Null);
            assert e5.ok;
            val bc4 = ChessLogic.applyHumanMove(e5.record, "f1", "c4", Null);
            assert bc4.ok;
            val nc6 = ChessLogic.applyHumanMove(bc4.record, "b8", "c6", Null);
            assert nc6.ok;
            val qh5 = ChessLogic.applyHumanMove(nc6.record, "d1", "h5", Null);
            assert qh5.ok;
            val nf6 = ChessLogic.applyHumanMove(qh5.record, "g8", "f6", Null);
            assert nf6.ok;
            val qxf7 = ChessLogic.applyHumanMove(nf6.record, "h5", "f7", Null);
            assert qxf7.ok;
            assert qxf7.record.status == GameStatus.Checkmate;
            assert qxf7.record.turn == Color.Black;
        }

        @Test
        void shouldTrackHalfMoveClockForFiftyMoveRule() {
            val game = ChessLogic.defaultGame();
            assert game.halfMoveClock == 0;
            // Pawn move resets clock
            val e4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            assert e4.record.halfMoveClock == 0;
            // Knight move increments clock
            val nc6 = ChessLogic.applyHumanMove(e4.record, "b8", "c6", Null);
            assert nc6.record.halfMoveClock == 1;
        }

        @Test
        void shouldUpdateScoresOnCapture() {
            // Set up a position where White can capture
            val game = ChessLogic.defaultGame();
            val e4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            val d5 = ChessLogic.applyHumanMove(e4.record, "d7", "d5", Null);
            val exd = ChessLogic.applyHumanMove(d5.record, "e4", "d5", Null);
            assert exd.ok;
            assert exd.record.playerScore == 1;
        }

        @Test
        void shouldBuildMoveHistoryCorrectly() {
            val game = ChessLogic.defaultGame();
            val e4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            assert e4.record.moveHistory.size == 1;
            MoveHistoryEntry entry = e4.record.moveHistory[0];
            assert entry.moveNumber == 1;
            assert entry.color == Color.White;
            assert entry.fromSquare == "e2";
            assert entry.toSquare == "e4";
            assert entry.piece == 'P';
            assert entry.capturedPiece == Null;

            val e5 = ChessLogic.applyHumanMove(e4.record, "e7", "e5", Null);
            assert e5.record.moveHistory.size == 2;
            MoveHistoryEntry entry2 = e5.record.moveHistory[1];
            assert entry2.color == Color.Black;
        }
    }

    /**
     * Tests for AI auto-move functionality.
     */
    class AutoMoveTests {
        @Test
        void shouldRejectAutoMoveWhenNotBlacksTurn() {
            val game = ChessLogic.defaultGame(); // White's turn
            val result = ChessLogic.autoMove(game, 12, 28, Null);
            assert !result.moved;
            assert result.message == "Ready for a move";
        }

        @Test
        void shouldRejectAutoMoveWhenGameIsOver() {
            val finished = new GameRecord(
                ChessLogic.defaultBoard(), Color.Black, GameStatus.Checkmate, Null,
                0, 0, new CastlingRights(), Null, [], Null, 0);
            val result = ChessLogic.autoMove(finished, 12, 28, Null);
            assert !result.moved;
        }

        @Test
        void shouldApplyAutoMoveWhenBlacksTurn() {
            // After e4, it's Black's turn
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            assert afterE4.turn == Color.Black;
            // Apply a valid Black move (e7-e5 = indices 12 -> 28)
            val result = ChessLogic.autoMove(afterE4, 12, 28, Null);
            assert result.moved;
            assert result.record.turn == Color.White;
            assert result.record.board[28] == 'p';
        }

        @Test
        void shouldHandleNoLegalMovesInAutoMove() {
            // After e4, it's Black's turn - pass invalid indices to signal no legal moves
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            val result = ChessLogic.autoMove(afterE4, -1, -1, Null);
            assert !result.moved;
            assert result.message == "No legal moves";
        }
    }
}
