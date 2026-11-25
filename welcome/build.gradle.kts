/*
 * Build file for the "welcome" example.
 *
 * Includes React webapp integration via webapp-conventions plugin.
 */

plugins {
    id("xtc-conventions")
    id("webapp-conventions")
}

xtcRun {
    module { moduleName = "welcomeTest" }
}
