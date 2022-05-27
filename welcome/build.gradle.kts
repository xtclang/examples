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

tasks.register<Copy>("updateXdk") {
    group       = "Build"
    description = "Update the xdk executables"

    var xvmHome = System.getProperty("xvm.home")
    if (xvmHome == null || xvmHome == "") {
        xvmHome = "../../../xvm"
    }

    val xdkExt = "$xvmHome/xdk/build/xdk"
    val xdkLib = "$serverDir/xdk"

    val srcTimestamp = fileTree(xdkExt).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dstTimestamp = fileTree(xdkLib).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (srcTimestamp > dstTimestamp) {
        from("$xdkExt") {
            include("bin/**")
            include("javatools/**")
            include("lib/**")
        }
        into("$xdkLib")
        doLast {
            println("Finished task: updateXdk")
        }
    }
    else {
        println("Xdk is up to date")
    }
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
        val stageDir = "$userHome/xqiz.it/platform"
        val account  = "acme"
        val libDir   = "$stageDir/$account/lib"

        println("Copying modules from ${serverDir}/build to $libDir")
        copy {
            from("${serverDir}/build")
            into(libDir)
        }
    }
}