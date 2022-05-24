/*
 * Main build file for the "platform" project.
 */

group = "welcome"
version = "0.1.0"

val server = project(":server");
val webapp = project(":webapp");

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    dependsOn(server.tasks["clean"])
    dependsOn(webapp.tasks["clean"])
}

val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(webapp.tasks["build"])
    dependsOn(server.tasks["build"])
}

tasks.register("upload") {
    group       = "Run"
    description = "Simulation of the application upload step"

    dependsOn(build)

    doLast {
        var devHome  = file("${rootProject.projectDir}/../..")
        val stageDir = "$devHome/staging/platform"
        val account  = "acme"
        val libDir   = "$stageDir/$account/lib"

        println("Copying modules from ${server.buildDir} to $libDir")
        copy {
            from("${server.buildDir}")
            into(libDir)
        }
    }
}