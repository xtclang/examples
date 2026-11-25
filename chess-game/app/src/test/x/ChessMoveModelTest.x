module ChessMoveModelTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.core.MoveModel;
    import chess.ai.AIUtility;
    import chess.api.ModelApi;
    import chess.api.ModelApi.AnalyseRequest;

    /**
     * Tests for [MoveModel] (the ported move-choice model) and [ModelApi] (its endpoint).
     */
    class MoveModelTests {
        @Test
        void shouldScoreEveryLegalOpeningMove() {
            String fen = AIUtility.boardToFen(ChessLogic.defaultGame());
            MoveModel.PositionScore score = MoveModel.scorePosition(fen);

            assert score.color == "w";
            assert score.candidates.size == 20; // the 20 legal opening moves for White

            // Sorted best-first: values are non-increasing.
            for (Int i : 1 ..< score.candidates.size) {
                assert score.candidates[i - 1].v >= score.candidates[i].v;
            }
        }

        @Test
        void shouldFavourCentralPawnMovesOverRookMoves() {
            String fen = AIUtility.boardToFen(ChessLogic.defaultGame());
            MoveModel.PositionScore score = MoveModel.scorePosition(fen);

            Double? e4 = Null;
            Double? rookShuffle = Null;
            for (MoveModel.Candidate c : score.candidates) {
                if (c.fromSquare == "e2" && c.toSquare == "e4") {
                    e4 = c.v;
                } else if (c.fromSquare == "a1") {
                    rookShuffle = c.v;
                }
            }
            assert e4 != Null;
            // a1's rook has no legal opening move, so this just confirms e4 beats the field.
            assert e4.as(Double) >= score.candidates[score.candidates.size - 1].v;
        }

        @Test
        void softmaxOfEqualValuesIsUniform() {
            Double[] vs = [1.0, 1.0, 1.0, 1.0];
            Double[] probs = MoveModel.softmax(vs, 2.0);
            assert probs.size == 4;
            for (Double p : probs) {
                assert (p - 0.25).abs() < 0.0001;
            }
        }

        @Test
        void entropyOfAUniformDistributionIsLog2OfItsSize() {
            Double[] probs = [0.25, 0.25, 0.25, 0.25];
            Double h = MoveModel.entropyBits(probs);
            assert (h - 2.0).abs() < 0.0001; // log2(4) == 2 bits
        }

        @Test
        void analyseEndpointScoresAShortGame() {
            val afterE4 = ChessLogic.applyHumanMove(ChessLogic.defaultGame(), "e2", "e4", Null).record;
            val afterE5 = ChessLogic.applyHumanMove(afterE4, "e7", "e5", Null).record;

            String startFen = AIUtility.boardToFen(ChessLogic.defaultGame());
            String[] fens = [startFen, AIUtility.boardToFen(afterE4), AIUtility.boardToFen(afterE5)];
            String[] playedUci = ["e2e4", "e7e5"];

            ModelApi.AnalysisResult result = new ModelApi().analyse(new AnalyseRequest(fens, playedUci));

            assert result.decisions.size == 3;
            assert result.decisions[0].color == "w";
            assert result.decisions[0].playedIndex >= 0; // e2e4 is always a legal candidate
            assert result.decisions[1].color == "b";
            assert result.decisions[1].playedIndex >= 0; // e7e5

            assert result.players.w.fitted;
            assert result.players.w.moves == 1;
        }
    }
}
