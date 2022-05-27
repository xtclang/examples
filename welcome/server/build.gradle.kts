/*
 * Build the "server" modules.
 */

val webapp = project(":webapp");
val xdkBin = "$projectDir/xdk/bin"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(buildDir)
}

tasks.register("build") {
    group       = "Build"
    description = "Build server modules"

    dependsOn(compileWelcome)
}

val compileWelcome = tasks.register("compileWelcome") {
    group       = "Build"
    description = "Compile welcome module"

    dependsOn(compileWelcomeDB)
    dependsOn(webapp.tasks["build"])

    doLast {
        val srcModule   = "${projectDir}/main/x/welcome.x"
        val resourceDir = "${projectDir}/main/resources"
        val libDir      = "$buildDir"

        val src  = file("$srcModule").lastModified()
        val rsrc = fileTree("$resourceDir").getFiles().stream().
                mapToLong({f -> f.lastModified()}).max().orElse(0)
        val dest = file("$libDir/welcome.xtc").lastModified()

        if (src > dest || rsrc > dest) {
            project.exec {
                commandLine("$xdkBin/xtc", "-verbose", "-rebuild",
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
    description = "Compile welcomeDB module"

    val srcModule = "${projectDir}/main/x/welcomeDB.x"
    val libDir    = "$buildDir"

    val src  = file("$srcModule").lastModified()
    val dest = file("$libDir/welcomeDB.xtc").lastModified()

    if (src > dest) {
        project.exec {
            commandLine("$xdkBin/xtc", "-verbose",
                        "-o", "$libDir",
                        "$srcModule")
        }
    }
    else {
        println("$libDir/welcomeDB.xtc is up to date")
        }
}