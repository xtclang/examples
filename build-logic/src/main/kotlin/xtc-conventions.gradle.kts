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
