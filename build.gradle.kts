/**
 * Root build file for examples repository.
 *
 * Applies XTC plugin and declares all module dependencies following the platform pattern.
 */

plugins {
    alias(libs.plugins.xtc)
}

group = "org.xtclang.examples"

subprojects {
    group = rootProject.group
}

dependencies {
    xdkDistribution(libs.xdk)

    xtcModule(projects.welcome)
    xtcModule(projects.banking)
    xtcModule(projects.counter)

    // Chess-game is an included composite build. Gradle's composite-build
    // dependency substitution routes these coordinate-based deps to the
    // matching subprojects (org.xtclang.examples:app -> :chess-game:app,
    // :db -> :chess-game:db). That brings chess.xtc and chessDB.xtc into
    // the root's xtcModule configuration so installDist picks them up.
    xtcModule("org.xtclang.examples:app")
    xtcModule("org.xtclang.examples:db")
}

/**
 * Assemble all compiled XTC modules into a single installation directory.
 *
 * After running `./gradlew installDist`, all .xtc files are collected in:
 *   build/install/examples/lib/
 *
 * You can then run any example with:
 *   xtc run -L build/install/examples/lib <moduleName>
 */
val installDist by tasks.registering(Copy::class) {
    group = "distribution"
    description = "Install all example modules to build/install/examples/lib"
    from(configurations.xtcModule)
    into(layout.buildDirectory.dir("install/examples/lib"))
}

/*
 * Attach the chess-game composite build to the root lifecycle so that
 * `./gradlew clean`, `./gradlew build`, and `./gradlew check` at the root
 * reach into it. Without this, included builds aren't joined to the root's
 * lifecycle tasks (see AGENTS.md: attachment is controlled separately from
 * inclusion).
 */
val chessGame = gradle.includedBuild("chess-game")
listOf("clean", "build", "check").forEach { name ->
    tasks.named(name) {
        dependsOn(chessGame.task(":$name"))
    }
}
