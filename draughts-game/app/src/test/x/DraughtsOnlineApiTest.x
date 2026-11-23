module DraughtsOnlineApiTest {
    package draughts import draughts.examples.org;
    package db       import draughtsDB.examples.org;

    import draughts.api.DraughtsApi;
    import draughts.api.OnlineApi;
    import draughts.api.OnlineApi.NameRequest;

    import db.models.GameRecord;
    import db.models.RoomRecord;
    import db.models.TimeControl;

    /**
     * Endpoint tests for the rooms service (`/api/online`), called the way requests would call it.
     */
    class OnlineApiTests {
        static String fresh(String label) {
            @Inject Random random;
            return $"{label}{random.int(1_000_000_000)}";
        }

        /**
         * A room with both players seated: the service, the room code, Black's id and White's id.
         */
        (OnlineApi, String, String, String) seatedRoom() {
            OnlineApi api   = new OnlineApi();
            val       made  = api.createRoom(new NameRequest("Ann"));
            val       joined = api.joinRoom(made.roomCode, new NameRequest("Bo"));
            assert joined.success;
            return api, made.roomCode, made.playerId, joined.playerId;
        }

        @Test
        void shouldCreateARoomAndSeatTheCreatorAsBlack() {
            OnlineApi api  = new OnlineApi();
            val       room = api.createRoom(new NameRequest("Ann"));

            assert room.success;
            assert room.roomCode.size == 6;
            assert room.playerId.size == 16;
            assert room.color == "Black";
            assert room.waiting;
            assert room.blackName == "Ann";
            assert room.board.size == 8;
            assert room.message.indexOf(room.roomCode);
            assert !room.yourTurn;
        }

        @Test
        void shouldGiveEachRoomItsOwnCode() {
            OnlineApi api = new OnlineApi();
            assert api.createRoom().roomCode != api.createRoom().roomCode;
        }

        @Test
        void shouldSeatTheJoinerAsWhiteAndStartTheGame() {
            OnlineApi api    = new OnlineApi();
            val       made   = api.createRoom(new NameRequest("Ann"));
            val       joined = api.joinRoom(made.roomCode, new NameRequest("Bo"));

            assert joined.success;
            assert joined.color == "White";
            assert joined.whiteName == "Bo";
            assert joined.blackName == "Ann";
            assert !joined.waiting;
            assert joined.playerId != made.playerId;

            // The creator now sees it is their move
            val creator = api.state(made.roomCode, made.playerId);
            assert !creator.waiting;
            assert creator.yourTurn;
            assert creator.message == "Your move.";
        }

        @Test
        void shouldRefuseAThirdPlayerAndAnUnknownRoom() {
            (OnlineApi api, String code, _, _) = seatedRoom();
            val third = api.joinRoom(code, new NameRequest("Cy"));
            assert !third.success;
            assert third.message == "This room is full.";

            val nowhere = api.joinRoom("NOPE00", new NameRequest("Cy"));
            assert !nowhere.success;
            assert api.state("NOPE00", "anyone").success == False;
        }

        @Test
        void shouldLetOnlyThePlayerToMoveMoveAndShowTheOtherTheResult() {
            (OnlineApi api, String code, String black, String white) = seatedRoom();

            // White cannot move first, and a stranger cannot move at all
            assert !api.move(code, white, "b6-a5").success;
            assert api.move(code, white, "b6-a5").message == "It is not your turn.";
            assert api.move(code, "stranger", "c3-d4").message == "You are not a player in this room.";

            val played = api.move(code, black, "c3-d4");
            assert played.success;
            assert played.history.size == 1;
            assert !played.yourTurn;

            // White sees Black's move, and now it is theirs
            val seen = api.state(code, white);
            assert seen.history.size == 1;
            assert seen.lastMove == "c3-d4";
            assert seen.yourTurn;
            assert seen.turn == "White";

            // Black cannot move twice in a row
            assert !api.move(code, black, "e3-f4").success;

            val reply = api.move(code, white, "b6-a5");
            assert reply.success;
            assert reply.history.size == 2;
            assert api.state(code, black).yourTurn;
        }

        @Test
        void shouldRefuseIllegalMovesAndLeaveTheGameAlone() {
            (OnlineApi api, String code, String black, _) = seatedRoom();
            val bad = api.move(code, black, "c3-c4");
            assert !bad.success;
            assert bad.history.empty;
            assert bad.yourTurn;
        }

        @Test
        void shouldNotAllowMovesBeforeAnOpponentJoins() {
            OnlineApi api  = new OnlineApi();
            val       made = api.createRoom(new NameRequest("Ann"));
            val       move = api.move(made.roomCode, made.playerId, "c3-d4");
            assert !move.success;
            assert move.message == "Waiting for an opponent to join.";
        }

        @Test
        void shouldOfferLegalMovesOnlyOnYourTurn() {
            (OnlineApi api, String code, String black, String white) = seatedRoom();
            val mine = api.legalMoves(code, black);
            assert mine.success;
            assert mine.moves.size == 7;
            assert !api.legalMoves(code, white).success;
            assert !api.legalMoves(code, "stranger").success;
        }

        @Test
        void shouldForfeitAGameInProgressWhenAPlayerLeaves() {
            (OnlineApi api, String code, String black, String white) = seatedRoom();
            api.move(code, black, "c3-d4");

            val left = api.leave(code, white);
            assert left.success;
            assert left.status == "BlackWins";

            val seen = api.state(code, black);
            assert seen.opponentLeft;
            assert seen.status == "BlackWins";
            assert seen.message == $"Bo left, so Ann wins.";

            // Nobody can move or rematch in a room somebody has left
            assert !api.move(code, black, "e3-f4").success;
            assert !api.rematch(code, black).success;
        }

        @Test
        void shouldCloseARoomNobodyJoined() {
            OnlineApi api  = new OnlineApi();
            val       made = api.createRoom(new NameRequest("Ann"));
            assert api.leave(made.roomCode, made.playerId).success;
            assert !api.state(made.roomCode, made.playerId).success;
        }

        @Test
        void shouldEndTheGameScoreItAndOfferARematch() {
            @Inject Random random;
            String ann = fresh("Ann");
            String bo  = fresh("Bo");
            OnlineApi api    = new OnlineApi();
            val       made   = api.createRoom(new NameRequest(ann));
            val       joined = api.joinRoom(made.roomCode, new NameRequest(bo));

            // Black is one jump from taking White's last piece
            String board = "........" + "..w....." + ".b......" + "........" +
                           "........" + "........" + "........" + "........";
            using (api.schema.createTransaction()) {
                api.schema.rooms.put(made.roomCode, new RoomRecord(made.roomCode,
                        new GameRecord(board, Black, Ongoing, ann, bo), made.playerId, joined.playerId));
            }

            // A rematch is refused while the game is still on
            assert !api.rematch(made.roomCode, made.playerId).success;

            val won = api.move(made.roomCode, made.playerId, "b6-d8");
            assert won.status == "BlackWins";
            assert won.message.startsWith($"{ann} (Black) wins");
            assert !api.move(made.roomCode, joined.playerId, "d8-e7").success;

            val table = new DraughtsApi().scores().table;
            assert table.any(r -> r.name == ann && r.won == 1 && r.points == 3);
            assert table.any(r -> r.name == bo && r.lost == 1);

            val again = api.rematch(made.roomCode, joined.playerId);
            assert again.success;
            assert again.status == "Ongoing";
            assert again.history.empty;
            assert again.blackName == ann;
            assert again.whiteName == bo;
            assert api.state(made.roomCode, made.playerId).yourTurn;
        }

        @Test
        void shouldHaveNoClockUnlessOneIsAskedFor() {
            OnlineApi api  = new OnlineApi();
            val       room = api.createRoom(new NameRequest("Ann"));
            assert !room.timed;
            assert !room.clockRunning;
        }

        @Test
        void shouldCreateATimedRoomWithAClockThatStartsAtTheFirstMove() {
            OnlineApi api    = new OnlineApi();
            val       made   = api.createRoom(new NameRequest("Ann", 300_000, 3_000));
            val       joined = api.joinRoom(made.roomCode, new NameRequest("Bo"));

            assert made.timed;
            assert made.blackMs == 300_000 && made.whiteMs == 300_000;
            assert made.incrementMs == 3_000;

            // Seated, but no move yet, so nothing is running
            val before = api.state(made.roomCode, made.playerId);
            assert !before.clockRunning;
            assert before.blackMs == 300_000;

            // Black's first move earns the increment and starts White's clock
            val moved = api.move(made.roomCode, made.playerId, "c3-d4");
            assert moved.clockRunning;
            assert moved.blackMs == 303_000;
            assert moved.whiteMs <= 300_000;
            assert api.state(made.roomCode, joined.playerId).whiteMs <= 300_000;
        }

        @Test
        void shouldEndTheGameWhenAPlayerRunsOutOfTimeAndScoreIt() {
            String ann = fresh("Ann");
            String bo  = fresh("Bo");
            OnlineApi api    = new OnlineApi();
            val       made   = api.createRoom(new NameRequest(ann, 60_000, 0));
            val       joined = api.joinRoom(made.roomCode, new NameRequest(bo));
            api.move(made.roomCode, made.playerId, "c3-d4");

            // Rewind White's clock: 55 seconds left a minute and a half ago
            @Inject Clock clock;
            using (api.schema.createTransaction()) {
                assert RoomRecord room := api.schema.rooms.get(made.roomCode);
                api.schema.rooms.put(made.roomCode, new RoomRecord(made.roomCode, room.game,
                        room.blackId, room.whiteId, Null,
                        new TimeControl(60_000, 0, 60_000, 55_000, clock.now - Duration.ofSeconds(90)),
                        False));
            }

            // Whoever asks next finds that White has lost on time
            val seen = api.state(made.roomCode, made.playerId);
            assert seen.status == "BlackWins";
            assert seen.message == $"{bo} ran out of time, so {ann} wins.";
            assert seen.whiteMs == 0;
            assert !seen.clockRunning;

            // It is final: no more moves, and the result is on the scoreboard exactly once
            assert !api.move(made.roomCode, joined.playerId, "b6-a5").success;
            assert api.state(made.roomCode, joined.playerId).status == "BlackWins";
            val table = new DraughtsApi().scores().table;
            assert table.any(r -> r.name == ann && r.won == 1 && r.played == 1);
            assert table.any(r -> r.name == bo && r.lost == 1 && r.played == 1);

            // A rematch starts the clocks afresh with the same time
            val again = api.rematch(made.roomCode, made.playerId);
            assert again.success;
            assert again.blackMs == 60_000 && again.whiteMs == 60_000;
            assert !again.clockRunning;
        }
    }
}
