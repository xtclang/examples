/**
 * Convention plugin for XTC modules.
 *
 * Applies the XTC plugin, configures Java toolchain for auto-provisioning
 * via the Foojay resolver, and declares the XDK distribution dependency.
 */

import org.gradle.api.artifacts.VersionCatalogsExtension

plugins {
    // Note: catalog aliases (libs.plugins.xtc) are unavailable in precompiled plugins {} blocks
    id("org.xtclang.xtc-plugin")
    `java-base`
}

// TODO: Hack until Gradle fixes full version catalog support from convention plugins.
val libs = extensions.getByType<VersionCatalogsExtension>().named("libs")
val javaVersion = libs.findVersion("java").get().toString()
val xdk = libs.findLibrary("xdk").get()

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(javaVersion))
    }
}

dependencies {
    xdkDistribution(xdk)
}

// Make `testXtc` fail the build when any xunit test fails. The plugin default
// is to only log failures and exit 0, which hides real regressions. The flag
// lives on the task itself; setting it on the xtcTest extension alone does
// not propagate, so configure every XtcTestTask directly.
tasks.withType<org.xtclang.plugin.tasks.XtcTestTask>().configureEach {
    failOnTestFailure.set(true)
}
