import db.models.TimeControl;
import db.models.Color;

/**
 * Time Control Service
 *
 * Manages time tracking for chess games:
 * - Initialize time controls for a new game
 * - Update time remaining after each move
 * - Check for time-based win conditions (timeout)
 * - Apply time increments (Fischer time)
 */
service TimeControlService {

    @Inject Timer timer;

    private Int currentTimeMs() {
        return timer.elapsed.milliseconds;
    }

    /**
     * Create a new time control with specified time (in milliseconds) and increment.
     * @param initialTimeMs Starting time for each player in milliseconds
     * @param incrementMs   Time increment added after each move (Fischer time)
     */
    TimeControl create(Int initialTimeMs, Int incrementMs) {
        return new TimeControl(initialTimeMs, initialTimeMs, incrementMs, currentTimeMs());
    }

    /**
     * Update time control after a move.
     * @param tc          Current time control
     * @param movedColor  Which player made the move
     * @param isFirstMove True if this is the first move (no time deducted)
     * @return Updated time control with adjusted times
     */
    TimeControl updateAfterMove(TimeControl tc, Color movedColor, Boolean isFirstMove = False) {
        Int now          = currentTimeMs();
        Int newWhiteTime = tc.whiteTimeMs;
        Int newBlackTime = tc.blackTimeMs;

        if (isFirstMove) {
            // First move — just apply increment, no time deducted
            if (movedColor == White) {
                newWhiteTime += tc.incrementMs;
            } else {
                newBlackTime += tc.incrementMs;
            }
        } else {
            Int elapsed = now - tc.lastMoveTime;

            if (movedColor == White) {
                newWhiteTime = (tc.whiteTimeMs - elapsed).maxOf(0) + tc.incrementMs;
            } else {
                newBlackTime = (tc.blackTimeMs - elapsed).maxOf(0) + tc.incrementMs;
            }
        }

        return new TimeControl(newWhiteTime, newBlackTime, tc.incrementMs, now);
    }

    /**
     * Check if the current player has run out of time.
     * @param tc          Current time control
     * @param currentTurn Whose turn it currently is
     * @return True if the current player has timed out
     */
    Boolean hasTimedOut(TimeControl tc, Color currentTurn) {
        Int elapsed = currentTimeMs() - tc.lastMoveTime;

        return currentTurn == White
            ? (tc.whiteTimeMs - elapsed) <= 0
            : (tc.blackTimeMs - elapsed) <= 0;
    }

    /**
     * Get remaining time for a player (accounting for current elapsed time).
     * @param tc    Current time control
     * @param color Which player to check
     * @return Time remaining in milliseconds (floored at 0)
     */
    Int getRemainingTime(TimeControl tc, Color color) {
        Int elapsed = currentTimeMs() - tc.lastMoveTime;

        return color == White
            ? (tc.whiteTimeMs - elapsed).maxOf(0)
            : (tc.blackTimeMs - elapsed).maxOf(0);
    }
}