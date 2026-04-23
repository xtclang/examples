rootProject.name = "build-logic"

gradle.beforeProject {
    if (version == Project.DEFAULT_VERSION) {
        version = "0.1.0"
    }
}

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
        gradlePluginPortal()
    }
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}
