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

// For projects with a Node.js-based webapp (e.g. welcome's React app), we need to
// run npm to build the webapp before XTC compilation. This block detects the presence
// of webapp/package.json and wires up the Node/npm build:
//   1. Configure Node.js to auto-download and point at the webapp/ directory
//   2. Register a buildWebapp task that runs `npm run build` with proper caching
//   3. Make processResources depend on buildWebapp so the compiled webapp output
//      is available as XTC module resources (used by @StaticContent annotations)
//
// Projects with only static HTML in webapp/public/ (banking, counter, chess-game)
// skip this block entirely — their content is picked up directly by the srcDir above.
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
