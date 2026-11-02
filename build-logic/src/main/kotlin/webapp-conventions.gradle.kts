/**
 * Convention plugin for XTC modules with webapp content.
 *
 * Adds the project's webapp content as a resource source, so that static
 * content can be served at runtime via @StaticContent.
 *
 * If webapp/package.json exists, the Node/npm plugin builds the webapp
 * (e.g. React/Vite) automatically before resource processing, and only the
 * build *output* (webapp/build) is exposed as a resource — not the npm
 * project itself (node_modules, raw src, config files). Projects with only
 * static HTML in webapp/public/ (banking, counter) expose the whole webapp/
 * directory as-is, since there's no build step to separate out.
 */

import com.github.gradle.node.npm.task.NpmTask

plugins {
    `java-base`
    // Note: catalog aliases (libs.plugins.node) are unavailable in precompiled plugins {} blocks
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

val hasNpmWebapp = file("webapp/package.json").exists()

sourceSets.named("main") {
    resources {
        // npm-based webapps (welcome, chess-game) only need their built
        // output; the npm project itself (node_modules, src, configs) would
        // otherwise get copied into the module's resources unnecessarily.
        srcDir(if (hasNpmWebapp) "webapp/build" else "webapp")
    }
}

// For projects with a Node.js-based webapp (e.g. welcome's React app), we need to
// run npm to build the webapp before XTC compilation. This block detects the presence
// of webapp/package.json and wires up the Node/npm build:
//   1. Configure Node.js to auto-download and point at the webapp/ directory
//   2. Register a buildWebapp task that runs `npm run build` with proper caching
//   3. Make processResources and processXtcResources depend on buildWebapp so the
//      compiled webapp output is available as XTC module resources (used by
//      @StaticContent annotations). Both tasks copy the webapp/build resource srcDir.
if (hasNpmWebapp) {
    node {
        download.set(providers.gradleProperty("node.download")
            .map { it.toBoolean() }
            .orElse(true))
        nodeProjectDir.set(file("webapp"))
    }

    val npmInstall = tasks.named("npmInstall")
    val processResources = tasks.named("processResources")
    val processXtcResources = tasks.named("processXtcResources")

    val buildWebapp = tasks.register<NpmTask>("buildWebapp") {
        args.set(listOf("run", "build"))
        workingDir.set(file("webapp"))
        dependsOn(npmInstall)

        inputs.dir("webapp/src")
        inputs.dir("webapp/public")
        inputs.file("webapp/index.html")
        inputs.file("webapp/vite.config.js")
        inputs.file("webapp/package.json")
        inputs.file("webapp/package-lock.json")

        outputs.dir("webapp/build")
        outputs.cacheIf { true }
    }

    processResources {
        dependsOn(buildWebapp)
    }

    processXtcResources {
        dependsOn(buildWebapp)
    }
}
