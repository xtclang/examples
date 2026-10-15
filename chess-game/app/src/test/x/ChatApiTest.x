module ChatApiTest {
    package chess import chess.examples.org;
    package db    import chessDB.examples.org;

    import chess.api.ChatApi;
    import chess.api.OnlineChessApi;
    import chess.core.OnlineChessLogic.RoomCreated;
    import chess.utils.ChatAPIResponseTypes.*;

    /**
     * Endpoint tests for the in-game chat service (`/api/chat`): sending, validation, who may
     * talk in a room, history and polling for new messages, against a real database.
     */
    class ChatApiTests {
        /**
         * A room with both seats taken, as (room code, White's id, Black's id).
         */
        static (String, String, String) fullRoom() {
            OnlineChessApi online  = new OnlineChessApi();
            RoomCreated    created = online.createRoom();
            val            joined  = online.joinRoom(created.roomCode);
            return created.roomCode, created.playerId, joined.playerId;
        }

        static SendMessageRequest say(String text) = new SendMessageRequest(text);

        @Test
        void shouldDeliverAMessageToTheRoom() {
            ChatApi chat = new ChatApi();
            (String room, String white, String black) = fullRoom();

            assert chat.sendMessage(room, white, say("good luck")).success;

            ChatHistoryResponse seenByBlack = chat.getHistory(room, black);
            assert seenByBlack.success;
            assert seenByBlack.messages.size == 1;
            assert seenByBlack.messages[0].message == "good luck";
            assert seenByBlack.messages[0].playerColor == "White";
            assert seenByBlack.messages[0].playerId == white;
        }

        @Test
        void shouldTrimWhitespaceAroundAMessage() {
            ChatApi chat = new ChatApi();
            (String room, String white, _) = fullRoom();

            chat.sendMessage(room, white, say("   gg   "));
            assert chat.getHistory(room, white).messages[0].message == "gg";
        }

        @Test
        void shouldRejectAnEmptyMessage() {
            ChatApi chat = new ChatApi();
            (String room, String white, _) = fullRoom();

            SendMessageResponse reply = chat.sendMessage(room, white, say("    "));
            assert !reply.success;
            assert reply.error == "Message cannot be empty";
            assert chat.getHistory(room, white).messages.empty;
        }

        @Test
        void shouldRejectAMessageOverFiveHundredCharacters() {
            ChatApi chat = new ChatApi();
            (String room, String white, _) = fullRoom();

            assert chat.sendMessage(room, white, say(new String(new Char[500](_ -> 'a')))).success;

            SendMessageResponse reply = chat.sendMessage(room, white, say(new String(new Char[501](_ -> 'a'))));
            assert !reply.success;
            assert reply.error?.indexOf("too long") : False;
        }

        @Test
        void shouldKeepStrangersOutOfARoom() {
            ChatApi chat = new ChatApi();
            (String room, _, _) = fullRoom();

            assert !chat.sendMessage(room, "stranger", say("hello")).success;

            ChatHistoryResponse history = chat.getHistory(room, "stranger");
            assert !history.success;
            assert history.messages.empty;
        }

        @Test
        void shouldReportAnUnknownRoom() {
            ChatApi chat = new ChatApi();

            assert chat.sendMessage("ZZZZZ9", "anyone", say("hi")).error == "Room not found";
            assert chat.getHistory("ZZZZZ9", "anyone").error == "Room not found";
            assert chat.getRecent("ZZZZZ9", "anyone", 0).error == "Room not found";
        }

        @Test
        void shouldKeepEachRoomsMessagesSeparate() {
            ChatApi chat = new ChatApi();
            (String roomA, String whiteA, _) = fullRoom();
            (String roomB, String whiteB, _) = fullRoom();

            chat.sendMessage(roomA, whiteA, say("only in A"));

            assert chat.getHistory(roomA, whiteA).messages.size == 1;
            assert chat.getHistory(roomB, whiteB).messages.empty;
        }

        @Test
        void shouldCapHistoryAtTheRequestedLimit() {
            ChatApi chat = new ChatApi();
            (String room, String white, String black) = fullRoom();

            chat.sendMessage(room, white, say("one"));
            chat.sendMessage(room, black, say("two"));
            chat.sendMessage(room, white, say("three"));

            assert chat.getHistory(room, white, 2).messages.size == 2;
            assert chat.getHistory(room, white).messages.size == 3;
        }

        @Test
        void shouldKeepTwoQuickMessagesFromTheSamePlayer() {
            ChatApi chat = new ChatApi();
            (String room, String white, _) = fullRoom();

            for (Int i : 1..5) {
                assert chat.sendMessage(room, white, say($"message {i}")).success;
            }
            assert chat.getHistory(room, white).messages.size == 5;
        }

        @Test
        void shouldReturnOnlyMessagesNewerThanSince() {
            ChatApi chat = new ChatApi();
            (String room, String white, String black) = fullRoom();

            chat.sendMessage(room, white, say("before"));
            Int mark = chat.getHistory(room, white).messages[0].timestamp;

            // Timestamps have millisecond resolution; make sure the next one is strictly later.
            @Inject Clock clock;
            Time start = clock.now;
            while (clock.now - start < Duration.ofMillis(3)) {}

            chat.sendMessage(room, black, say("after"));

            ChatHistoryResponse recent = chat.getRecent(room, white, mark);
            assert recent.success;
            assert recent.messages.size == 1;
            assert recent.messages[0].message == "after";
        }
    }
}
