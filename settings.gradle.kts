// we don't really need this; just to make IDEA happy
rootProject.name = "example"

dependencyResolutionManagement {
    repositories {
        gradlePluginPortal()
    }
}

includeBuild("welcome")
//includeBuild("banking")
//includeBuild("counter")
