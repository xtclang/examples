/*
 * Main build file for the "welcome" example.
 */

group = "welcome"
version = "0.1.0"

val server = project(":server");
val webapp = project(":webapp");

val webappDir = "${webapp.projectDir}"
val serverDir = "${server.projectDir}"

val webContent = "$serverDir/main/resources/webapp"
val xdkExe     = "$serverDir/xdk/bin"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    dependsOn(server.tasks["clean"])
    dependsOn(webapp.tasks["clean"])
}

tasks.register("upload") {
    group       = "Run"
    description = "Simulation of the application upload step"

    dependsOn(build)

    doLast {
        var devHome  = file("${projectDir}/../..")
        val stageDir = "$devHome/staging/platform"
        val account  = "acme"
        val libDir   = "$stageDir/$account/lib"

        println("Copying modules from ${serverDir}/build to $libDir")
        copy {
            from("${serverDir}/build")
            into(libDir)
        }
    }
}
val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(buildServer)
}

// ----- server build tasks ------------------------------------------------------------------------

val buildServer = tasks.register("buildServer") {
    group       = "Build"
    description = "Compile server modules"

    dependsOn(compileWelcome)
}

val compileWelcome = tasks.register("compileWelcome") {
    group       = "Build"
    description = "Compile welcome module"

    dependsOn(compileWelcomeDB)
    dependsOn(buildWebApp)

    doLast {
        val srcModule   = "${serverDir}/main/x/welcome.x"
        val resourceDir = "${serverDir}/main/resources"
        val libDir      = "${serverDir}/build"

        val src  = file("$srcModule").lastModified()
        val rsrc = fileTree("$resourceDir").getFiles().stream().
                mapToLong({f -> f.lastModified()}).max().orElse(0)
        val dest = file("$libDir/welcome.xtc").lastModified()

        if (src > dest || rsrc > dest) {
            project.exec {
                commandLine("$xdkExe/xtc", "-verbose", "-rebuild",
                            "-o", "$libDir",
                            "-L", "$libDir",
                            "$srcModule")
            }
        }
        else {
            println("$libDir/welcome.xtc is up to date")
            }
    }
}

val compileWelcomeDB = tasks.register("compileWelcomeDB") {
    group       = "Build"
    description = "Compile welcome module"

    val srcModule = "${serverDir}/main/x/welcomeDB.x"
    val libDir    = "${serverDir}/build"

    val src  = file("$srcModule").lastModified()
    val dest = file("$libDir/welcomeDB.xtc").lastModified()

    if (src > dest) {
        project.exec {
            commandLine("$xdkExe/xtc", "-verbose",
                        "-o", "$libDir",
                        "$srcModule")
        }
    }
    else {
        println("$libDir/welcomeDB.xtc is up to date")
        }
}

tasks.register<Copy>("updateXdk") {

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

// ----- webapp build tasks ------------------------------------------------------------------------

val buildWebApp = tasks.register("buildWebApp") {

    val src1 = fileTree("$webappDir/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val src2 = fileTree("$webappDir/public").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dest = fileTree("$webContent").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (src1 > dest || src2 > dest) {
        dependsOn(copyContent)
        }
    else {
        println("$webContent is up to date")
        }
}

val copyContent = tasks.register("copyContent") {
    dependsOn(npmBuild)

    doLast {
        println("Copying static content from $$webappDir/build to $webContent")

        copy {
            from("$webappDir/build")
            into(webContent)
        }
    }
}

val npmBuild = tasks.register("npmBuild") {
    project.exec {
        workingDir(webappDir)
        commandLine("npm", "run", "build")
    }
}