/*
 * Build the "server" modules.
 */

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete("$buildDir")
}