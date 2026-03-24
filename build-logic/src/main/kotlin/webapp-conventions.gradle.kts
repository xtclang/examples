/**
 * Convention plugin for webapp integration with XTC modules.
 *
 * Applies to XTC modules that include a webapp (React or static content).
 * Builds the webapp and integrates the output as XTC module resources.
 */

import com.github.gradle.node.npm.task.NpmTask

plugins {
    id("org.xtclang.xtc-plugin")
    id("com.github.node-gradle.node")
}

// The node plugin overrides repository settings, so re-declare them
repositories {
    // mavenLocal {
    //     content {
    //         includeGroup("org.xtclang")
    //     }
    // }
    maven {
        url = uri("https://central.sonatype.com/repository/maven-snapshots/")
        mavenContent {
            snapshotsOnly()
        }
    }
    mavenCentral()
}

node {
    download.set(providers.gradleProperty("node.download")
        .map { it.toBoolean() }
        .orElse(true))
    nodeProjectDir.set(file("${project.projectDir}/webapp"))
}

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

sourceSets {
    named("main") {
        resources {
            srcDir("${project.projectDir}/webapp")
        }
    }
}

tasks.named<Copy>("processResources") {
    dependsOn(buildWebapp)
}
