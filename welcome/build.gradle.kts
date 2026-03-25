/*
 * Build file for the "welcome" example.
 *
 * Includes React webapp integration via webapp-conventions plugin.
 */

plugins {
    id("xtc-conventions")
    id("webapp-conventions")
}

node {
    version.set(libs.versions.nodejs)
    npmVersion.set(libs.versions.npm)
}

xtcRun {
    module { moduleName = "welcomeTest" }
}
