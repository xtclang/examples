/*
 * Settings for the chess-game composite build.
 *
 * Contains two XTC modules compiled as separate subprojects:
 *   :db  → chessDB.xtc (database schema, compiled first)
 *   :app → chess.xtc   (web application, depends on :db)
 *
 * Kept as its own included build so the root settings don't have to enumerate
 * chess-game's internal subprojects.
 */

pluginManagement {
    includeBuild("../build-logic")

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
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "chess-game"

include(":db")
include(":app")
