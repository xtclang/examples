import db.models.TimeControl;
import db.models.RoomRecord;

/**
 * RoomSettlement - ends a timed game whose clock has run out.
 *
 * Nothing on the server watches the clocks, so every request that reads a room calls `settle`
 * first. See GameClock for the clock arithmetic.
 */
service RoomSettlement {
    /**
     * If the player to move has run out of time, end the game: the other player wins, and the
     * result goes on the room's scoreboard. The room is returned as it now stands; calling this
     * again changes nothing, so a result is never recorded twice.
     */
    static RoomRecord settle(DraughtsSchema schema, Time now, String roomCode, RoomRecord room) {
        TimeControl? tc   = room.timeControl;
        GameRecord   game = room.game;
        if (tc == Null || room.whiteId == Null || game.status != Ongoing
                || !GameClock.timedOut(tc, game.turn, !game.history.empty, now)) {
            return room;
        }
        GameRecord over = new GameRecord(game.board, game.turn,
                game.turn == Black ? WhiteWins : BlackWins, game.blackName, game.whiteName,
                game.quietPlies, game.lastMove, game.history, game.level);
        RoomRecord settled = new RoomRecord(roomCode, over, room.blackId, room.whiteId, room.leftId,
                // the clock of the player who ran out reads zero
                game.turn == Black
                        ? new TimeControl(tc.initialMs, tc.incrementMs, 0, tc.whiteMs, now)
                        : new TimeControl(tc.initialMs, tc.incrementMs, tc.blackMs, 0, now),
                True);
        schema.rooms.put(roomCode, settled);
        Scoreboard.record(schema, Scoreboard.roomScope(roomCode), over);
        return settled;
    }
}
