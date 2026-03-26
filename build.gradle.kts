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
    xtcModule(projects.chessGame)
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
