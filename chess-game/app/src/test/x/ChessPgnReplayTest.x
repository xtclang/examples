module ChessPgnReplayTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.core.FenParser;
    import chess.core.PgnReplay;
    import chess.core.PgnReplay.Frame;
    import chess.ai.AIUtility;

    /**
     * Tests for [FenParser] (FEN -> GameRecord) and [PgnReplay] (SAN movetext -> frames).
     */
    class FenParserTests {
        @Test
        void shouldRoundTripTheStandardStartingPosition() {
            val start = ChessLogic.defaultGame();
            val fen = AIUtility.boardToFen(start);
            val parsed = FenParser.fromFen(fen);
            assert parsed.board == start.board;
            assert parsed.turn == start.turn;
            assert parsed.castlingRights == start.castlingRights;
            assert parsed.enPassantTarget == start.enPassantTarget;
        }

        @Test
        void shouldRoundTripAnArbitraryMidGamePosition() {
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            val afterE5 = ChessLogic.applyHumanMove(afterE4, "e7", "e5", Null).record;
            val fen = AIUtility.boardToFen(afterE5);
            val parsed = FenParser.fromFen(fen);
            assert parsed.board == afterE5.board;
            assert parsed.turn == afterE5.turn;
        }

        @Test
        void shouldParseCastlingAndEnPassantFields() {
            val parsed = FenParser.fromFen("8/8/8/3pP3/8/8/8/4K2R w K d6 0 1");
            assert parsed.castlingRights.whiteKingside;
            assert !parsed.castlingRights.whiteQueenside;
            assert !parsed.castlingRights.blackKingside;
            assert !parsed.castlingRights.blackQueenside;
            assert parsed.enPassantTarget == "d6";
        }
    }

    class PgnReplayTests {
        @Test
        void shouldReplayASimpleOpeningFromTheStandardStart() {
            val start = ChessLogic.defaultGame();
            val startFen = AIUtility.boardToFen(start);
            Frame[] frames = PgnReplay.replay(startFen, "1. e4 e5 2. Nf3 Nc6");

            assert frames.size == 5; // start + 4 plies
            assert frames[0].fen == startFen;
            assert frames[1].toSquare == "e4";
            assert frames[2].toSquare == "e5";
            assert frames[3].toSquare == "f3";
            assert frames[4].toSquare == "c6";
        }

        @Test
        void shouldResolveDisambiguatedAndCapturingMoves() {
            // 1. e4 d5 2. exd5 -- a pawn capture that needs the from-file disambiguator.
            Frame[] frames = PgnReplay.replay(
                    AIUtility.boardToFen(ChessLogic.defaultGame()), "1. e4 d5 2. exd5");
            assert frames.size == 4;
            assert frames[3].fromSquare == "e4";
            assert frames[3].toSquare == "d5";
        }

        @Test
        void shouldStopAtAnUnresolvableToken() {
            Frame[] frames = PgnReplay.replay(
                    AIUtility.boardToFen(ChessLogic.defaultGame()), "1. e4 e5 2. Xy9");
            // "Xy9" matches no legal move in any position -- replay should stop after the two
            // moves it could resolve rather than throwing.
            assert frames.size == 3;
        }

        @Test
        void shouldReplayCastlingFromAnArbitraryFen() {
            // White to castle kingside; king on e1, rook on h1, path clear.
            Frame[] frames = PgnReplay.replay("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "O-O");
            assert frames.size == 2;
            assert frames[1].fromSquare == "e1";
            assert frames[1].toSquare == "g1";
            assert frames[1].board[61] == 'R'; // f1, the rook that castled
        }
    }
}
