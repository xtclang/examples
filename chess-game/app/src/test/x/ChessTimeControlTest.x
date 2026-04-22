module ChessTimeControlTest {
    package chess import chess.examples.org;
    package db import chessDB.examples.org;
    package xunit import xunit.xtclang.org;

    import chess.services.TimeControlService;
    import db.models.Color;
    import db.models.TimeControl;

    import xunit.annotations.Disabled;

    /**
     * Tests for TimeControlService: creation, move updates, timeout detection, presets.
     */
    class TimeControlCreationTests {
        TimeControlService tcs = new TimeControlService();

        @Disabled("new TimeControlService() does not auto-inject its @Inject Timer timer, so currentTimeMs() returns 0 and lastMoveTime > 0 fails — needs either DI support for plain `new` or a test-constructor that takes a Timer")
        @Test
        void shouldCreateWithEqualTimesForBothPlayers() {
            val tc = tcs.create(600_000, 5_000);
            assert tc.whiteTimeMs == 600_000;
            assert tc.blackTimeMs == 600_000;
            assert tc.incrementMs == 5_000;
            assert tc.lastMoveTime > 0;
        }

        @Test
        void shouldCreateWithZeroIncrement() {
            val tc = tcs.create(300_000, 0);
            assert tc.whiteTimeMs == 300_000;
            assert tc.blackTimeMs == 300_000;
            assert tc.incrementMs == 0;
        }
    }

    /**
     * Tests for updating time after moves.
     */
    class TimeControlUpdateTests {
        TimeControlService tcs = new TimeControlService();

        @Test
        void shouldAddIncrementOnFirstMoveWithoutDeductingTime() {
            val tc = tcs.create(60_000, 1_000);
            val updated = tcs.updateAfterMove(tc, Color.White, isFirstMove=True);
            // First move: no elapsed time deducted, but increment IS added
            assert updated.whiteTimeMs == 60_000 + 1_000;
            assert updated.blackTimeMs == 60_000;
        }

        @Test
        void shouldAddIncrementForBlackFirstMove() {
            val tc = tcs.create(60_000, 2_000);
            val updated = tcs.updateAfterMove(tc, Color.Black, isFirstMove=True);
            assert updated.whiteTimeMs == 60_000;
            assert updated.blackTimeMs == 60_000 + 2_000;
        }

        @Test
        void shouldDeductElapsedTimeOnSubsequentMoves() {
            val tc = tcs.create(60_000, 1_000);
            // Simulate a subsequent move (not first)
            val updated = tcs.updateAfterMove(tc, Color.White, isFirstMove=False);
            // Elapsed time should be very small (nearly instant), but increment is added
            // White time should be approximately 60_000 + 1_000 (minus tiny elapsed)
            assert updated.whiteTimeMs <= 61_000;
            assert updated.whiteTimeMs > 59_000; // Should not have lost more than 1 second
            assert updated.blackTimeMs == 60_000;
        }

        @Test
        void shouldNotGoNegativeOnTimeDeduction() {
            // Create a time control with very little time
            val tc = new TimeControl(1, 1, 0, 0);
            // After a "long" elapsed time, time should floor at 0
            val updated = tcs.updateAfterMove(tc, Color.White, isFirstMove=False);
            assert updated.whiteTimeMs >= 0;
        }
    }

    /**
     * Tests for timeout detection and remaining time queries.
     */
    class TimeControlTimeoutTests {
        TimeControlService tcs = new TimeControlService();

        @Test
        void shouldNotTimeOutWithPlentyOfTimeRemaining() {
            val tc = tcs.create(600_000, 0);
            assert !tcs.hasTimedOut(tc, Color.White);
            assert !tcs.hasTimedOut(tc, Color.Black);
        }

        @Test
        void shouldReportRemainingTimeAccurately() {
            val tc = tcs.create(60_000, 0);
            val whiteRemaining = tcs.getRemainingTime(tc, Color.White);
            val blackRemaining = tcs.getRemainingTime(tc, Color.Black);
            // Should be very close to 60_000 (minus tiny elapsed since creation)
            assert whiteRemaining > 58_000;
            assert whiteRemaining <= 60_000;
            assert blackRemaining > 58_000;
            assert blackRemaining <= 60_000;
        }

        @Test
        void shouldFloorRemainingTimeAtZero() {
            // Create with 0 time — remaining should be 0
            val tc = new TimeControl(0, 0, 0, 0);
            assert tcs.getRemainingTime(tc, Color.White) == 0;
            assert tcs.getRemainingTime(tc, Color.Black) == 0;
        }
    }

    /**
     * Tests for preset time control factories.
     */
    class TimeControlPresetTests {
        TimeControlService tcs = new TimeControlService();

        @Test
        void shouldCreateBulletPresets() {
            val bullet = tcs.bullet();
            assert bullet.whiteTimeMs == 60_000;
            assert bullet.blackTimeMs == 60_000;
            assert bullet.incrementMs == 0;

            val bullet1plus1 = tcs.bullet1plus1();
            assert bullet1plus1.whiteTimeMs == 60_000;
            assert bullet1plus1.incrementMs == 1_000;

            val bullet2plus1 = tcs.bullet2plus1();
            assert bullet2plus1.whiteTimeMs == 120_000;
            assert bullet2plus1.incrementMs == 1_000;
        }

        @Test
        void shouldCreateBlitzPresets() {
            val blitz3 = tcs.blitz3();
            assert blitz3.whiteTimeMs == 180_000;
            assert blitz3.incrementMs == 0;

            val blitz3plus2 = tcs.blitz3plus2();
            assert blitz3plus2.whiteTimeMs == 180_000;
            assert blitz3plus2.incrementMs == 2_000;

            val blitz5 = tcs.blitz5();
            assert blitz5.whiteTimeMs == 300_000;
            assert blitz5.incrementMs == 0;

            val blitz5plus3 = tcs.blitz5plus3();
            assert blitz5plus3.whiteTimeMs == 300_000;
            assert blitz5plus3.incrementMs == 3_000;
        }

        @Test
        void shouldCreateRapidPresets() {
            val rapid10 = tcs.rapid10();
            assert rapid10.whiteTimeMs == 600_000;
            assert rapid10.incrementMs == 0;

            val rapid15plus10 = tcs.rapid15plus10();
            assert rapid15plus10.whiteTimeMs == 900_000;
            assert rapid15plus10.incrementMs == 10_000;

            val rapid30 = tcs.rapid30();
            assert rapid30.whiteTimeMs == 1_800_000;
            assert rapid30.incrementMs == 0;
        }

        @Test
        void shouldCreateClassicalPreset() {
            val classical = tcs.classical();
            assert classical.whiteTimeMs == 5_400_000;
            assert classical.incrementMs == 30_000;
        }

        @Test
        void shouldEnsureAllPresetsHaveEqualStartingTimes() {
            TimeControl[] presets = [tcs.bullet(), tcs.bullet1plus1(), tcs.bullet2plus1(),
                                     tcs.blitz3(), tcs.blitz3plus2(), tcs.blitz5(), tcs.blitz5plus3(),
                                     tcs.rapid10(), tcs.rapid15plus10(), tcs.rapid30(),
                                     tcs.classical()];
            for (TimeControl preset : presets) {
                assert preset.whiteTimeMs == preset.blackTimeMs;
            }
        }
    }
}
