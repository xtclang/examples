import core.DraughtsGame;
import db.models.TimeControl;
import db.models.RoomRecord;
import api.OnlineApi.RoomState;

/**
 * RoomView - builds the responses the room endpoints send.
 *
 * A room is stored once but looks different to each player: their side, whether it is their turn,
 * and the text on the status line all depend on who is asking.
 */
service RoomView {
    /**
     * The response for a room that does not exist.
     */
    static RoomState notFound(String roomCode) {
        return new RoomState(False, $"Room {roomCode} was not found.", roomCode);
    }

    /**
     * The room's current state, with a message saying why a request was refused.
     */
    static RoomState refuse(Time now, RoomRecord room, String playerId, String message) {
        return stateFor(now, room, playerId, message, False);
    }

    /**
     * The room as one player sees it.
     *
     * @param now      the time the clocks are read at
     * @param message  text for the status line, or Null to describe the room's situation
     * @param success  False if this answers a refused request
     */
    static RoomState stateFor(Time now, RoomRecord room, String playerId, String? message,
                              Boolean success = True) {
        GameRecord game    = room.game;
        Color?     mine    = RoomIdentity.colorOf(room, playerId);
        Boolean    waiting = room.whiteId == Null;
        Boolean    yours   = RoomIdentity.isYourTurn(room, playerId);
        Boolean    capture = yours
                && DraughtsRules.legalMoves(game.board, game.turn)[0].captures.size > 0;
        Boolean    ongoing = game.status == Ongoing;

        TimeControl? tc      = room.timeControl;
        Boolean      running = tc != Null && !waiting && ongoing && !game.history.empty;

        String text;
        if (message != Null) {
            text = message;
        } else if (waiting) {
            text = $"Waiting for an opponent. Share the code {room.code}.";
        } else if (room.timedOut) {
            String loser  = game.status == WhiteWins ? game.blackName : game.whiteName;
            String winner = game.status == WhiteWins ? game.whiteName : game.blackName;
            text = $"{loser} ran out of time, so {winner} wins.";
        } else if (room.leftId != Null) {
            String leaver = room.leftId == room.blackId ? game.blackName : game.whiteName;
            String winner = room.leftId == room.blackId ? game.whiteName : game.blackName;
            text = ongoing ? $"{leaver} left the game." : $"{leaver} left, so {winner} wins.";
        } else if (!ongoing) {
            text = DraughtsGame.describeState(game, False);
        } else if (yours) {
            text = capture ? "Your move - you must capture." : "Your move.";
        } else {
            String name = game.turn == Black ? game.blackName : game.whiteName;
            text = $"{name} to move.";
        }

        return new RoomState(success, text, room.code,
                mine == Null ? "" : playerId,
                mine?.toString() : "",
                waiting, room.leftId != Null, yours,
                DraughtsGame.boardRows(game.board),
                game.turn.toString(), game.status.toString(), game.lastMove,
                game.blackName, game.whiteName,
                DraughtsRules.countPieces(game.board, Black),
                DraughtsRules.countPieces(game.board, White),
                capture, game.history,
                tc != Null,
                tc == Null ? 0 : GameClock.remaining(tc, Black, game.turn, running, now),
                tc == Null ? 0 : GameClock.remaining(tc, White, game.turn, running, now),
                tc == Null ? 0 : tc.incrementMs,
                running);
    }
}
