import db.models.TimeControl;

/**
 * GameClock - the arithmetic of a timed room's clocks.
 *
 * Each player's bank of time runs down only while it is their turn and the game is under way
 * (the first move has been made, and the game is not over). A move takes the time spent on it off
 * the mover's bank and adds the increment. Reading the clocks is free of side effects: a player to
 * move whose time has run out is the caller's business (see OnlineApi), not this service's.
 *
 * Times are wall-clock `Time`s kept in the room, not a timer that belongs to one running process,
 * so a game's clocks survive the server being restarted.
 */
service GameClock {
    /**
     * The shortest and longest a player's bank can start with, and the longest increment.
     */
    static Int MIN_MS        = 30_000;
    static Int MAX_MS        = 10_800_000;
    static Int MAX_INCREMENT = 60_000;

    /**
     * The clocks for a new game, or Null if `initialMs` is not positive (no clock).
     */
    static TimeControl? start(Time now, Int initialMs, Int incrementMs) {
        if (initialMs <= 0) {
            return Null;
        }
        Int initial   = initialMs.maxOf(MIN_MS).minOf(MAX_MS);
        Int increment = incrementMs.maxOf(0).minOf(MAX_INCREMENT);
        return new TimeControl(initial, increment, initial, initial, now);
    }

    /**
     * Milliseconds since the last move.
     */
    static Int sinceLastMove(TimeControl tc, Time now) = (now - tc.lastMoveTime).milliseconds.maxOf(0);

    /**
     * What a player has left right now. The clock of the player to move runs while the game is
     * `running`; the other's is as it was.
     */
    static Int remaining(TimeControl tc, Color color, Color turn, Boolean running, Time now) {
        Int stored = color == Black ? tc.blackMs : tc.whiteMs;
        return running && turn == color ? (stored - sinceLastMove(tc, now)).maxOf(0) : stored;
    }

    /**
     * True if the player to move has run out of time.
     */
    static Boolean timedOut(TimeControl tc, Color turn, Boolean running, Time now) {
        return running && remaining(tc, turn, turn, True, now) <= 0;
    }

    /**
     * The clocks after `mover` has moved: the time the move took comes off their bank (nothing
     * comes off for the first move of the game) and the increment goes on.
     */
    static TimeControl afterMove(TimeControl tc, Color mover, Boolean firstMove, Time now) {
        Int stored = mover == Black ? tc.blackMs : tc.whiteMs;
        Int left   = (firstMove ? stored : (stored - sinceLastMove(tc, now)).maxOf(0)) + tc.incrementMs;
        return mover == Black
                ? new TimeControl(tc.initialMs, tc.incrementMs, left, tc.whiteMs, now)
                : new TimeControl(tc.initialMs, tc.incrementMs, tc.blackMs, left, now);
    }
}
