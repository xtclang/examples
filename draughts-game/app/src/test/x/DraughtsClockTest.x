module DraughtsClockTest {
    package draughts import draughts.examples.org;
    package db       import draughtsDB.examples.org;

    import draughts.core.GameClock;
    import db.models.TimeControl;

    /**
     * The arithmetic of a timed room's clocks.
     */
    class GameClockTests {
        static Time at(Int seconds) = Time.EPOCH + Duration.ofSeconds(seconds);

        static Time t0() = at(0);

        /**
         * Clocks that must exist.
         */
        static TimeControl begin(Int ms, Int increment) {
            TimeControl? tc = GameClock.start(t0(), ms, increment);
            assert tc != Null;
            return tc;
        }

        @Test
        void shouldGiveBothPlayersTheStartingTime() {
            TimeControl tc = begin(300_000, 2_000);
            assert tc.blackMs == 300_000 && tc.whiteMs == 300_000;
            assert tc.initialMs == 300_000 && tc.incrementMs == 2_000;
        }

        @Test
        void shouldHaveNoClockForNoTime() {
            assert GameClock.start(t0(), 0, 0) == Null;
            assert GameClock.start(t0(), -5, 0) == Null;
        }

        @Test
        void shouldKeepTimesAndIncrementsWithinLimits() {
            TimeControl tiny = begin(1_000, 999_999);
            assert tiny.initialMs == GameClock.MIN_MS;
            assert tiny.incrementMs == GameClock.MAX_INCREMENT;
            TimeControl huge = begin(999_999_999, -4);
            assert huge.initialMs == GameClock.MAX_MS;
            assert huge.incrementMs == 0;
        }

        @Test
        void shouldRunOnlyTheClockOfThePlayerToMove() {
            TimeControl tc = begin(300_000, 0);
            // 20 seconds into the game, with Black to move
            assert GameClock.remaining(tc, Black, Black, True, at(20)) == 280_000;
            assert GameClock.remaining(tc, White, Black, True, at(20)) == 300_000;
        }

        @Test
        void shouldNotRunBeforeTheFirstMoveOrAfterTheGame() {
            TimeControl tc = begin(300_000, 0);
            assert GameClock.remaining(tc, Black, Black, False, at(120)) == 300_000;
            assert !GameClock.timedOut(tc, Black, False, at(99_999));
        }

        @Test
        void shouldTakeTheMoveTimeOffAndAddTheIncrement() {
            TimeControl tc = begin(300_000, 5_000);
            // The first move costs nothing, and earns the increment
            TimeControl first = GameClock.afterMove(tc, Black, True, at(40));
            assert first.blackMs == 305_000;
            assert first.whiteMs == 300_000;
            assert first.lastMoveTime == at(40);

            // White thinks for 30 seconds
            TimeControl second = GameClock.afterMove(first, White, False, at(70));
            assert second.whiteMs == 300_000 - 30_000 + 5_000;
            assert second.blackMs == 305_000;
            assert second.lastMoveTime == at(70);
        }

        @Test
        void shouldNeverGoBelowZeroAndShouldDetectTimingOut() {
            TimeControl tc = begin(30_000, 0);
            assert !GameClock.timedOut(tc, Black, True, at(29));
            assert GameClock.timedOut(tc, Black, True, at(30));
            assert GameClock.remaining(tc, Black, Black, True, at(500)) == 0;
            assert GameClock.afterMove(tc, Black, False, at(500)).blackMs == 0;
        }
    }
}
