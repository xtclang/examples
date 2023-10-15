import org.gradle.language.base.plugins.LifecycleBasePlugin.BUILD_GROUP
import org.gradle.language.base.plugins.LifecycleBasePlugin.BUILD_TASK_NAME

/*
 * Main build file for the "welcome" example.
 */

plugins {
    base
    //id("org.xvm.xtc-plugin")
    id("com.dorongold.task-tree").version("2.1.1")
}

group = "welcome"
version = "0.1.0"

val server = project(":server")
val webapp = project(":webapp")

val serverDir = "${server.projectDir}"

val build = tasks.named(BUILD_TASK_NAME) {
    dependsOn(server.tasks["build"])
}

val upload by tasks.registering {
    group       = "Run"
    description = "Simulation of the application upload step"

    dependsOn(build)

    doLast {
        val userHome = System.getProperty("user.home")
        val stageDir = "$userHome/xqiz.it/users"
        val account  = "acme"
        val libDir   = "$stageDir/$account/lib"
        logger.lifecycle("Copying modules from $serverDir/build to $libDir")
        copy {
            from("$serverDir/build")
            into(libDir)
            rename("(.+).xtc", "$1.examples.org.xtc")
        }
    }
}
