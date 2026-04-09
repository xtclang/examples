@file:Suppress("UnstableApiUsage")

rootProject.name = "cardGame"

pluginManagement {
    repositories {
        mavenLocal()
        maven("https://central.sonatype.com/repository/maven-snapshots/") {
            mavenContent { snapshotsOnly() }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenLocal()
        maven("https://central.sonatype.com/repository/maven-snapshots/") {
            mavenContent { snapshotsOnly() }
        }
        mavenCentral()
    }
}
