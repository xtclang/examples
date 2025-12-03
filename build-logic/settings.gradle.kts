rootProject.name = "build-logic"

dependencyResolutionManagement {
    repositories {
        mavenLocal {
            content {
                includeGroup("org.xtclang")
            }
        }
        maven {
            url = uri("https://central.sonatype.com/repository/maven-snapshots/")
            mavenContent {
                snapshotsOnly()
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}
