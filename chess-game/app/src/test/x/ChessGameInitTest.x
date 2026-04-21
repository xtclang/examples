module ChessGameInitTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.core.ChessGame;
    import chess.core.ChessGame.MoveOutcome;

    import db.models.Color;
    import db.models.CastlingRights;
    import db.models.GameRecord;
    import db.models.GameStatus;
    import db.models.MoveHistoryEntry;

    /**
     * Tests for game initialization, default state and board setup.
     */
    class GameInitializationTests {
        @Test
        void shouldCreateDefaultAndResetGames() {
            String board = ChessLogic.defaultBoard();
            assert board.size == 64;
            assert ChessLogic.boardRows(board)[0] == "rnbqkbnr";
            assert ChessLogic.boardRows(board)[7] == "RNBQKBNR";

            GameRecord game = ChessLogic.defaultGame();
            assert game.board == board;
            assert game.turn == Color.White;
            assert game.status == GameStatus.Ongoing;
            assert game.castlingRights.whiteKingside;
            assert game.moveHistory.empty;

            GameRecord reset = ChessLogic.resetGame();
            assert reset.board == board;
            assert reset.turn == Color.White;
        }

        @Test
        void shouldHaveCorrectInitialPiecePlacement() {
            GameRecord game = ChessLogic.defaultGame();
            // Black back rank
            assert game.board[0] == 'r';
            assert game.board[4] == 'k';
            // Black pawns
            for (Int i : 8 ..< 16) {
                assert game.board[i] == 'p';
            }
            // Empty middle
            for (Int i : 16 ..< 48) {
                assert game.board[i] == '.';
            }
            // White pawns
            for (Int i : 48 ..< 56) {
                assert game.board[i] == 'P';
            }
            // White back rank
            assert game.board[56] == 'R';
            assert game.board[60] == 'K';
        }

        @Test
        void shouldHaveAllCastlingRightsAndZeroClocks() {
            GameRecord game = ChessLogic.defaultGame();
            assert game.castlingRights.whiteKingside;
            assert game.castlingRights.whiteQueenside;
            assert game.castlingRights.blackKingside;
            assert game.castlingRights.blackQueenside;
            assert game.halfMoveClock == 0;
            assert game.playerScore == 0;
            assert game.opponentScore == 0;
            assert game.enPassantTarget == Null;
            assert game.lastMove == Null;
            assert game.timeControl == Null;
        }

        @Test
        void shouldApplyAStandardPawnMove() {
            GameRecord game = ChessLogic.defaultGame();
            MoveOutcome result = ChessLogic.applyHumanMove(game, "e2", "e4", Null);
            assert result.ok;
            assert result.record.turn == Color.Black;
            assert result.record.lastMove == "e2e4";
            assert result.record.board[36] == 'P';
            assert result.record.board[52] == '.';
            assert result.record.moveHistory.size == 1;
        }

        @Test
        void shouldRejectInvalidHumanMoveInput() {
            GameRecord game = ChessLogic.defaultGame();
            MoveOutcome result = ChessLogic.applyHumanMove(game, "zz", "e4", Null);
            assert !result.ok;
            assert result.message == "Invalid square format";
        }

        @Test
        void shouldRejectMoveWhenGameIsAlreadyFinished() {
            // Create a game record with Checkmate status
            GameRecord finished = new GameRecord(
                ChessLogic.defaultBoard(), Color.White, GameStatus.Checkmate, Null,
                0, 0, new CastlingRights(), Null, [], Null, 0);
            MoveOutcome result = ChessLogic.applyHumanMove(finished, "e2", "e4", Null);
            assert !result.ok;
            assert result.message == "Game already finished";

            // Same for Stalemate
            GameRecord stale = new GameRecord(
                ChessLogic.defaultBoard(), Color.White, GameStatus.Stalemate, Null,
                0, 0, new CastlingRights(), Null, [], Null, 0);
            MoveOutcome staleResult = ChessLogic.applyHumanMove(stale, "e2", "e4", Null);
            assert !staleResult.ok;
            assert staleResult.message == "Game already finished";
        }

        @Test
        void shouldFormatMoveNotation() {
            assert ChessLogic.createMoveNotation('P', 52, 36, False, Null, False, False, Null) == "e4";
            assert ChessLogic.createMoveNotation('N', 62, 45, False, Null, True, False, Null) == "Ne3+";
            assert ChessLogic.createMoveNotation('K', 60, 62, False, Null, False, False, "O-O") == "O-O";
            assert ChessLogic.createMoveNotation('p', 8, 0, False, 'Q', False, True, Null) == "a8=Q#";
        }

        @Test
        void shouldFormatCaptureNotation() {
            // Pawn capture
            assert ChessLogic.createMoveNotation('P', 52, 43, True, Null, False, False, Null) == "xd3";
            // Knight capture with check
            assert ChessLogic.createMoveNotation('N', 62, 45, True, Null, True, False, Null) == "Nxe3+";
            // Queen capture with checkmate
            assert ChessLogic.createMoveNotation('Q', 59, 4, True, Null, False, True, Null) == "Qxe8#";
        }
    }

    /**
     * Tests for legacy checkGameStatus method.
     */
    class LegacyStatusTests {
        @Test
        void shouldDetectOngoingGameViaLegacyStatus() {
            assert ChessGame.checkGameStatus(ChessLogic.defaultBoard(), Color.White) == GameStatus.Ongoing;
        }

        @Test
        void shouldDetectMissingKingAsCheckmate() {
            // Board with no black king
            String noBlackKing = "rnbq.bnr" +
                                 "pppppppp" +
                                 "........" +
                                 "........" +
                                 "........" +
                                 "........" +
                                 "PPPPPPPP" +
                                 "RNBQKBNR";
            assert ChessGame.checkGameStatus(noBlackKing, Color.Black) == GameStatus.Checkmate;
        }

        @Test
        void shouldDetectLoneKingsAsStalemate() {
            String loneKings = "....k..." +
                               "........" +
                               "........" +
                               "........" +
                               "........" +
                               "........" +
                               "........" +
                               "....K...";
            assert ChessGame.checkGameStatus(loneKings, Color.White) == GameStatus.Stalemate;
        }
    }
}
