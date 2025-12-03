/**
 * Convention plugin for React webapp integration with XTC modules.
 *
 * Applies to XTC modules that include a React webapp, following the platformUI pattern.
 */

import com.github.gradle.node.npm.task.NpmTask
import org.gradle.api.tasks.Copy

plugins {
    id("org.xtclang.xtc-plugin")
    id("com.github.node-gradle.node")
}

// Node plugin overrides repository settings, so re-declare them
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
}

// XDK dependency - consuming project must declare this
// (convention plugins should not reference version catalog)

// Configure node plugin for webapp
node {
    download.set(providers.gradleProperty("node.download")
        .map { it.toBoolean() }
        .orElse(true))
    // Version configuration should be done in the consuming project
    // or via gradle.properties
    nodeProjectDir.set(file("${project.projectDir}/webapp"))
}

// Custom npm build task with proper caching
val buildWebapp by tasks.registering(NpmTask::class) {
    args.set(listOf("run", "build"))
    workingDir.set(file("${project.projectDir}/webapp"))
    dependsOn(tasks.named("npmInstall"))

    inputs.dir("$projectDir/webapp/src")
    inputs.dir("$projectDir/webapp/public")
    inputs.file("$projectDir/webapp/package.json")
    inputs.file("$projectDir/webapp/package-lock.json")

    outputs.dir("$projectDir/webapp/build")
    outputs.cacheIf { true }
}

// Integrate webapp build output as resources
sourceSets {
    named("main") {
        resources {
            srcDir("${project.projectDir}/webapp/build")
        }
    }
}

tasks.named<Copy>("processResources") {
    dependsOn(buildWebapp)
}
