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
 * 
 * Note: Time tracking uses a simple counter for demonstration.
 * In production, this would use actual system time.
 */
service TimeControlService {
    /**
     * Get current time in milliseconds.
     * Note: This is simplified for demonstration.
     * In production, this would integrate with system time.
     */
    @Inject Clock clock;
    private Int currentTimeMs() {
        return clock.now.timeOfDay.milliseconds;
    }

    /**
     * Create a new time control with specified time (in milliseconds) and increment.
     * @param initialTimeMs Starting time for each player in milliseconds
     * @param incrementMs Time increment added after each move (Fischer time)
     */
    TimeControl create(Int initialTimeMs, Int incrementMs) {
        Int now = currentTimeMs();
        return new TimeControl(initialTimeMs, initialTimeMs, incrementMs, now);
    }

    /**
     * Update time control after a move.
     * @param tc Current time control
     * @param movedColor Which player made the move
     * @return Updated time control with adjusted times
     */
    TimeControl updateAfterMove(TimeControl tc, Color movedColor) {
        Int now = currentTimeMs();
        Int elapsed = now - tc.lastMoveTime;

        Int newWhiteTime = tc.whiteTimeMs;
        Int newBlackTime = tc.blackTimeMs;

        if (movedColor == White) {
            newWhiteTime = (tc.whiteTimeMs - elapsed).maxOf(0);
            // Add increment
            newWhiteTime += tc.incrementMs;
        } else {
            newBlackTime = (tc.blackTimeMs - elapsed).maxOf(0);
            // Add increment
            newBlackTime += tc.incrementMs;
        }

        return new TimeControl(newWhiteTime, newBlackTime, tc.incrementMs, now);
    }

    /**
     * Check if a player has run out of time.
     * @param tc Current time control
     * @param currentTurn Whose turn it currently is
     * @return True if the current player has timed out
     */
    Boolean hasTimedOut(TimeControl tc, Color currentTurn) {
        Int now = currentTimeMs();
        Int elapsed = now - tc.lastMoveTime;

        if (currentTurn == White) {
            return (tc.whiteTimeMs - elapsed) <= 0;
        } else {
            return (tc.blackTimeMs - elapsed) <= 0;
        }
    }

    /**
     * Get remaining time for a player (accounting for current elapsed time).
     * @param tc Current time control
     * @param color Which player to check
     * @return Time remaining in milliseconds
     */
    Int getRemainingTime(TimeControl tc, Color color) {
        Int now = currentTimeMs();
        Int elapsed = now - tc.lastMoveTime;

        if (color == White) {
            return (tc.whiteTimeMs - elapsed).maxOf(0);
        } else {
            return (tc.blackTimeMs - elapsed).maxOf(0);
        }
    }

    /**
     * Common time control presets (in milliseconds).
     */
    TimeControl bullet() = create(60_000, 0);           // 1 minute, no increment
    TimeControl blitz() = create(300_000, 0);          // 5 minutes, no increment
    TimeControl rapid() = create(600_000, 0);          // 10 minutes, no increment
    TimeControl classic() = create(1_800_000, 0);      // 30 minutes, no increment
    TimeControl fischerBlitz() = create(180_000, 2_000); // 3 minutes + 2 seconds
}
