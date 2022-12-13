/*
 * Main build file for the "welcome" example.
 */

group = "welcome"
version = "0.1.0"

val server = project(":server");
val webapp = project(":webapp");

val serverDir = "${server.projectDir}"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    dependsOn(server.tasks["clean"])
    dependsOn(webapp.tasks["clean"])
}

val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(server.tasks["build"])
}

tasks.register("upload") {
    group       = "Run"
    description = "Simulation of the application upload step"

    dependsOn(build)

    doLast {
        val userHome = System.getProperty("user.home")
        val stageDir = "$userHome/xqiz.it/users"
        val account  = "acme"
        val libDir   = "$stageDir/$account/lib"

        println("Copying modules from ${serverDir}/build to $libDir")
        copy {
            from("${serverDir}/build")
            into(libDir)
        }
    }
}