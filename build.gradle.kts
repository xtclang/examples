/**
 * Root build file for examples repository.
 *
 * Applies XTC plugin and declares all module dependencies following the platform pattern.
 */

plugins {
    alias(libs.plugins.xtc)
}

group = "org.xtclang.examples"

// Propagate group to all subprojects (version comes from gradle.properties)
subprojects {
    group = rootProject.group
}

dependencies {
    // Declare XDK distribution
    xdkDistribution(libs.xdk)

    // Declare all module dependencies
    xtcModule(projects.welcome)
    xtcModule(projects.banking)
    xtcModule(projects.counter)
}
