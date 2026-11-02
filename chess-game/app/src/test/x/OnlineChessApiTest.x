module OnlineChessApiTest {
    package chess import chess.examples.org;
    package db    import chessDB.examples.org;

    import chess.api.OnlineChessApi;
    import chess.core.OnlineChessLogic.RoomCreated;

    /**
     * Endpoint tests for the two-player service (`/api/online`): creating and joining rooms,
     * turn order, moves, valid moves, reset and leaving, against a real database.
     */
    class OnlineChessApiTests {
        /**
         * A room with both seats taken, as (api, room code, White's id, Black's id).
         */
        static (OnlineChessApi, String, String, String) fullRoom() {
            OnlineChessApi api     = new OnlineChessApi();
            RoomCreated    created = api.createRoom();
            val            joined  = api.joinRoom(created.roomCode);
            return api, created.roomCode, created.playerId, joined.playerId;
        }

        @Test
        void shouldCreateARoomWithAShareableCode() {
            OnlineChessApi api     = new OnlineChessApi();
            RoomCreated    created = api.createRoom();

            assert created.roomCode.size == 6;
            for (Char ch : created.roomCode) {
                assert ch.asciiUppercase() || ch.asciiDigit();
            }
            assert created.playerId.size > 0;
        }

        @Test
        void shouldSeatTheCreatorAsWhiteAndWaitForAnOpponent() {
            OnlineChessApi api     = new OnlineChessApi();
            RoomCreated    created = api.createRoom();
            val            state   = api.getState(created.roomCode, created.playerId);

            assert state.playerColor == "White";
            assert state.waitingForOpponent;
            assert !state.isYourTurn;
        }

        @Test
        void shouldSeatTheSecondPlayerAsBlack() {
            (OnlineChessApi api, String room, String white, String black) = fullRoom();

            assert black.size > 0 && black != white;
            assert api.getState(room, black).playerColor == "Black";
            assert api.getState(room, white).isYourTurn;
            assert !api.getState(room, black).isYourTurn;
        }

        @Test
        void shouldTurnAwayAThirdPlayer() {
            (OnlineChessApi api, String room, _, _) = fullRoom();

            val third = api.joinRoom(room);
            assert third.message == "Room is full.";
            assert third.playerColor == "Spectator";
        }

        @Test
        void shouldReportAnUnknownRoom() {
            OnlineChessApi api = new OnlineChessApi();

            assert api.joinRoom("ZZZZZ9").message == "Room not found.";
            assert api.getState("ZZZZZ9", "anyone").message == "Room not found.";
        }

        @Test
        void shouldPlayAMoveAndPassTheTurn() {
            (OnlineChessApi api, String room, String white, String black) = fullRoom();

            val afterWhite = api.makeMove(room, white, "e2", "e4");
            assert afterWhite.turn == "Black";
            assert afterWhite.lastMove == "e2e4";
            assert api.getState(room, black).isYourTurn;

            val afterBlack = api.makeMove(room, black, "e7", "e5");
            assert afterBlack.turn == "White";
            assert afterBlack.moveHistory.size == 2;
        }

        @Test
        void shouldRefuseAMoveOutOfTurn() {
            (OnlineChessApi api, String room, String white, String black) = fullRoom();

            val state = api.makeMove(room, black, "e7", "e5");
            assert state.turn == "White";
            assert state.moveHistory.empty;
        }

        @Test
        void shouldRefuseAMoveBeforeTheOpponentArrives() {
            OnlineChessApi api     = new OnlineChessApi();
            RoomCreated    created = api.createRoom();

            val state = api.makeMove(created.roomCode, created.playerId, "e2", "e4");
            assert state.moveHistory.empty;
        }

        @Test
        void shouldListValidMovesOnlyForThePlayerToMove() {
            (OnlineChessApi api, String room, String white, String black) = fullRoom();

            val mine = api.getValidMoves(room, white, "e2");
            assert mine.success;
            assert mine.validMoves.contains("e3") && mine.validMoves.contains("e4");

            assert api.getValidMoves(room, black, "e7").validMoves.empty;
            assert !api.getValidMoves(room, "stranger", "e2").success;
        }

        @Test
        void shouldResetTheBoardForBothPlayers() {
            (OnlineChessApi api, String room, String white, String black) = fullRoom();
            api.makeMove(room, white, "e2", "e4");

            val state = api.resetGame(room, white);
            assert state.moveHistory.empty;
            assert state.turn == "White";
            assert api.getState(room, black).moveHistory.empty;
        }

        @Test
        void shouldStartAClockWhenTheRoomHasATimeControl() {
            OnlineChessApi api     = new OnlineChessApi();
            RoomCreated    created = api.createRoom(new OnlineChessApi.CreateRoomRequest(180_000, 2_000));

            assert val clock ?= api.getState(created.roomCode, created.playerId).timeControl;
            assert clock.incrementMs == 2_000;
        }

        @Test
        void shouldCloseTheRoomWhenAPlayerLeaves() {
            (OnlineChessApi api, String room, String white, _) = fullRoom();

            val left = api.leaveGame(room, white);
            assert left.message.indexOf("left the game");
        }
    }
}
