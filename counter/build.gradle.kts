/*
 * Main build file for the "banking" example.
 */

group = "banking"
version = "0.1.0"

val server = project(":server");
val webapp = project(":webapp");

val serverDir = "${server.projectDir}"

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

            rename("(.+).xtc", "$1.examples.org.xtc")
        }
    }
}