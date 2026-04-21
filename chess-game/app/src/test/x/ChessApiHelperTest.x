module ChessApiHelperTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;

    import chess.core.ChessLogic;
    import chess.api.ChessApi;
    import chess.utils.ChatAPIResponseTypes.*;

    import db.models.GameRecord;

    /**
     * Tests for single-player API helper methods.
     */
    class ChessApiHelperTests {
        @Test
        void shouldDescribeSinglePlayerState() {
            ChessApi api = new ChessApi();
            GameRecord fresh = ChessLogic.defaultGame();
            assert api.isOpponentPending(fresh) == False;
            assert api.describeState(fresh, False) == "Your move.";

            GameRecord afterE4 = ChessLogic.applyHumanMove(fresh, "e2", "e4", Null).record;
            assert api.describeState(afterE4, False) == "Opponent moved e2e4. Your move.";

            ChessApi.ApiState state = api.toApiState(fresh, Null, "session-1");
            assert state.turn == "White";
            assert state.status == "Ongoing";
            assert state.opponentPending == False;
            assert state.board[0] == "rnbqkbnr";
        }

        @Test
        void shouldBuildOnlineAndChatResponseTypes() {
            SendMessageRequest request = new SendMessageRequest(" hello chess ");
            assert request.message == " hello chess ";

            ChatMessageResponse message = new ChatMessageResponse("p1", "White", "hi", 123);
            assert message.playerId == "p1";
            assert message.playerColor == "White";
            assert message.message == "hi";
            assert message.timestamp == 123;

            ChatHistoryResponse history = new ChatHistoryResponse(True, Null, [message]);
            assert history.success;
            assert history.messages.size == 1;

            SendMessageResponse sent = new SendMessageResponse(True, Null, "Message sent successfully");
            assert sent.success;
            assert sent.message == "Message sent successfully";
        }

        @Test
        void shouldBuildApiStateWithCorrectBoardLayout() {
            ChessApi api = new ChessApi();
            GameRecord game = ChessLogic.defaultGame();
            ChessApi.ApiState state = api.toApiState(game, Null, "test-session");
            assert state.board.size == 8;
            assert state.board[0] == "rnbqkbnr";
            assert state.board[1] == "pppppppp";
            assert state.board[6] == "PPPPPPPP";
            assert state.board[7] == "RNBQKBNR";
            assert state.sessionId == "test-session";
        }

        @Test
        void shouldDescribeStateAfterMultipleMoves() {
            ChessApi api = new ChessApi();
            GameRecord game = ChessLogic.defaultGame();
            GameRecord afterE4 = ChessLogic.applyHumanMove(game, "e2", "e4", Null).record;
            // After Black responds (simulate via autoMove or manual), describe should include last move
            assert api.describeState(afterE4, False).contains("e2e4");
        }

        @Test
        void shouldBuildFailedChatResponses() {
            ChatHistoryResponse failed = new ChatHistoryResponse(False, "Room not found", []);
            assert !failed.success;
            assert failed.error == "Room not found";
            assert failed.messages.empty;

            SendMessageResponse failSend = new SendMessageResponse(False, "Not a player", Null);
            assert !failSend.success;
            assert failSend.error == "Not a player";
        }
    }
}
