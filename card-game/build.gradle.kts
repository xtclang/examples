/*
 * Build file for the "card-game" example.
 *
 * A console XTC application (no webapp), so it applies only the shared
 * xtc-conventions build-logic plugin. The compiled XTC module is `cardGame`.
 */

plugins {
    id("xtc-conventions")
}

// Run configuration - can be overridden from command line:
//   ./gradlew :card-game:runXtc --module=other --method=main --args=arg1,arg2
xtcRun {
    module {
        moduleName = "cardGame"
    }
}
