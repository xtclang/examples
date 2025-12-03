/*
 * Main build file for the "welcome" example.
 *
 * Includes React webapp integration via webapp-conventions plugin.
 */

plugins {
    id("webapp-conventions")
}

dependencies {
    xdkDistribution(libs.xdk)
}

// Configure Node.js versions
node {
    version.set(libs.versions.nodejs)
    npmVersion.set(libs.versions.npm)
}
