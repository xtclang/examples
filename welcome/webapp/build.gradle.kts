/*
 * Build the "webapp" content.
 */

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete("$buildDir")
}