/*
 * Root build file for the chess-game composite build.
 *
 * chess-game itself produces no artifacts; it aggregates the :db and :app
 * subprojects. This file sets the group and version that the subprojects
 * inherit, matching the examples repository convention.
 *
 * The `lifecycle-base` plugin gives the composite root the standard clean /
 * build / check tasks; subprojects are attached to them explicitly below so
 * that invoking a lifecycle task at the chess-game root (or from the outer
 * examples build via `includedBuild(...).task(":...")`) recurses into :db
 * and :app.
 */

plugins {
    `lifecycle-base`
}

group = "org.xtclang.examples"
version = "0.1.0-SNAPSHOT"

subprojects {
    group = rootProject.group
    version = rootProject.version
}

listOf("clean", "build", "check").forEach { name ->
    tasks.named(name) {
        dependsOn(subprojects.map { "${it.path}:$name" })
    }
}
