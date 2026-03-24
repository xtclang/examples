/*
 * Build file for the "welcome" example.
 *
 * Includes React webapp integration via webapp-conventions plugin.
 */

plugins {
    id("webapp-conventions")
}

dependencies {
    xdkDistribution(libs.xdk)
}

node {
    version.set(libs.versions.nodejs)
    npmVersion.set(libs.versions.npm)
}

xtcRun {
    module { moduleName = "welcomeTest" }
}
