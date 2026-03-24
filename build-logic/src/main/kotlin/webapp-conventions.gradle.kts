/**
 * Convention plugin for XTC modules with webapp content.
 *
 * Adds the project's webapp/ directory as a resource source, so that
 * @StaticContent annotations can reference paths like /public/index.html.
 *
 * If webapp/package.json exists, the Node/npm plugin builds the webapp
 * (e.g. React) automatically before XTC compilation.
 */

import com.github.gradle.node.npm.task.NpmTask

plugins {
    id("org.xtclang.xtc-plugin")
    id("com.github.node-gradle.node")
}

// The node plugin overrides repository settings, so re-declare them
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

sourceSets {
    main {
        resources {
            srcDir("webapp")
        }
    }
}

if (file("webapp/package.json").exists()) {
    node {
        download.set(providers.gradleProperty("node.download")
            .map { it.toBoolean() }
            .orElse(true))
        nodeProjectDir.set(file("webapp"))
    }

    val npmInstall by tasks.existing
    val processResources by tasks.existing

    val buildWebapp by tasks.registering(NpmTask::class) {
        args.set(listOf("run", "build"))
        workingDir.set(file("webapp"))
        dependsOn(npmInstall)

        inputs.dir("webapp/src")
        inputs.dir("webapp/public")
        inputs.file("webapp/package.json")
        inputs.file("webapp/package-lock.json")

        outputs.dir("webapp/build")
        outputs.cacheIf { true }
    }

    processResources {
        dependsOn(buildWebapp)
    }
}
