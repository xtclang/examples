/**
 * Root settings for examples repository.
 *
 * Multi-project build following XTC Gradle plugin conventions.
 */

pluginManagement {
    includeBuild("build-logic")

    repositories {
        // Maven Local for local development (checked first for local plugin builds)
        mavenLocal {
            content {
                includeGroup("org.xtclang")
                includeGroup("org.xtclang.xtc-plugin")
            }
        }
        // Maven Central Snapshots for snapshot artifacts
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}


plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

dependencyResolutionManagement {
    repositories {
        // Maven Local for local development (checked first for local XDK builds)
        mavenLocal {
            content {
                includeGroup("org.xtclang")
            }
        }
        // Maven Central Snapshots for snapshot artifacts
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        // Maven Central for release artifacts
        mavenCentral()
    }
}

rootProject.name = "examples"

// Include all example projects as flat modules
include(":welcome")
include(":banking")
include(":counter")
