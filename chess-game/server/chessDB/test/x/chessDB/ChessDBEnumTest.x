module ChessDBEnumTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;

    import db.models.Color;
    import db.models.GameMode;
    import db.models.GameStatus;
    import db.models.CastlingRights;
    import db.models.MoveHistoryEntry;
    import db.models.TimeControl;
    import db.models.GameRecord;
    import db.models.OnlineGame;
    import db.models.ChatMessage;

    /**
     * Tests for core enum values, value objects, and record construction.
     */
    class EnumAndValueObjectTests {
        @Test
        void shouldExposeCoreEnumValues() {
            assert Color.values.size == 2;
            assert GameMode.values.size == 2;
            assert GameStatus.values.size == 7;
        }

        @Test
        void shouldConstructCastlingRightsWithDefaults() {
            CastlingRights rights = new CastlingRights();
            assert rights.whiteKingside;
            assert rights.whiteQueenside;
            assert rights.blackKingside;
            assert rights.blackQueenside;
            assert rights.toString().size > 0;
        }

        @Test
        void shouldConstructCastlingRightsWithCustomValues() {
            CastlingRights noWhite = new CastlingRights(False, False, True, True);
            assert !noWhite.whiteKingside;
            assert !noWhite.whiteQueenside;
            assert noWhite.blackKingside;
            assert noWhite.blackQueenside;

            CastlingRights none = new CastlingRights(False, False, False, False);
            assert !none.whiteKingside;
            assert !none.blackQueenside;
        }

        @Test
        void shouldConstructTimeControl() {
            TimeControl tc = new TimeControl(60000, 59000, 1000, 12345);
            assert tc.whiteTimeMs == 60000;
            assert tc.blackTimeMs == 59000;
            assert tc.incrementMs == 1000;
            assert tc.lastMoveTime == 12345;
        }

        @Test
        void shouldConstructMoveHistoryEntry() {
            MoveHistoryEntry entry = new MoveHistoryEntry(1, Color.White, "e2", "e4", 'P');
            assert entry.moveNumber == 1;
            assert entry.color == Color.White;
            assert entry.fromSquare == "e2";
            assert entry.toSquare == "e4";
            assert entry.piece == 'P';
        }

        @Test
        void shouldConstructMoveHistoryEntryForBlack() {
            MoveHistoryEntry entry = new MoveHistoryEntry(1, Color.Black, "e7", "e5", 'p');
            assert entry.moveNumber == 1;
            assert entry.color == Color.Black;
            assert entry.fromSquare == "e7";
            assert entry.toSquare == "e5";
            assert entry.piece == 'p';
        }

        @Test
        void shouldConstructChatMessage() {
            ChatMessage message = new ChatMessage("ROOM01", "player-1", Color.Black, "hello", new Time(0));
            assert message.roomCode == "ROOM01";
            assert message.playerColor == Color.Black;
            assert message.message == "hello";
        }

        @Test
        void shouldConstructChatMessageForWhite() {
            ChatMessage msg = new ChatMessage("ROOM02", "player-2", Color.White, "good game", new Time(0));
            assert msg.roomCode == "ROOM02";
            assert msg.playerColor == Color.White;
            assert msg.message == "good game";
        }
    }

    /**
     * Tests for GameRecord and OnlineGame round-trip conversions.
     */
    class GameRecordTests {
        @Test
        void shouldRoundTripGameAndOnlineGameRecords() {
            GameRecord record = ChessLogic.defaultGame();
            assert record.board == ChessLogic.defaultBoard();
            assert record.turn == Color.White;
            assert record.status == GameStatus.Ongoing;
            assert record.castlingRights.whiteKingside;
            assert record.moveHistory.empty;

            OnlineGame online = OnlineGame.fromGameRecord(record, "ROOM01", "white-1", Null, GameMode.Multiplayer);
            assert online.roomCode == "ROOM01";
            assert online.whitePlayerId == "white-1";
            assert online.blackPlayerId == Null;
            assert online.mode == GameMode.Multiplayer;
            assert online.isWaitingForOpponent();
            assert online.hasPlayer("white-1");
            assert online.getPlayerColor("white-1") == Color.White;
            assert !online.hasOpponentLeft("white-1");

            (OnlineGame joined, String blackId) = chess.core.OnlineChessLogic.addSecondPlayer(online, new ecstasy.numbers.PseudoRandom());
            assert joined.blackPlayerId == blackId;
            assert joined.isFull();
            assert joined.getPlayerColor(blackId) == Color.Black;

            GameRecord backToRecord = joined.toGameRecord();
            assert backToRecord.board == record.board;
            assert backToRecord.turn == record.turn;
        }

        @Test
        void shouldCreateOnlineGameFromRecord() {
            GameRecord record = ChessLogic.defaultGame();
            OnlineGame online = OnlineGame.fromGameRecord(record, "TEST01", "w1", "b1", GameMode.Multiplayer);
            assert online.roomCode == "TEST01";
            assert online.whitePlayerId == "w1";
            assert online.blackPlayerId == "b1";
            assert online.isFull();
            assert !online.isWaitingForOpponent();
        }

        @Test
        void shouldDetectWaitingForOpponent() {
            GameRecord record = ChessLogic.defaultGame();
            OnlineGame waiting = OnlineGame.fromGameRecord(record, "W01", "w1", Null, GameMode.Multiplayer);
            assert waiting.isWaitingForOpponent();
            assert !waiting.isFull();
        }

        @Test
        void shouldDetectPlayerPresence() {
            GameRecord record = ChessLogic.defaultGame();
            OnlineGame game = OnlineGame.fromGameRecord(record, "PLAYER01", "w1", "b1", GameMode.Multiplayer);
            assert game.hasPlayer("w1");
            assert game.hasPlayer("b1");
            assert !game.hasPlayer("unknown");
        }
    }
}
