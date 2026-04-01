/**
 * Root settings for examples repository.
 *
 * Multi-project composite build following XTC Gradle plugin conventions.
 */

pluginManagement {
    includeBuild("build-logic")

    repositories {
        // Uncomment for local XDK development:
        // mavenLocal { content { includeGroup("org.xtclang"); includeGroup("org.xtclang.xtc-plugin") } }
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
        // Uncomment for local XDK development:
        // mavenLocal { content { includeGroup("org.xtclang") } }
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        mavenCentral()
    }
}

rootProject.name = "examples"

// Include all example projects
include(":welcome")
include(":banking")
include(":counter")
include(":chess-game")
include(":shopping")
