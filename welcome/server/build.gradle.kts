/*
 * Build the "server" modules.
 */

val appModuleName  = "welcome"
val dbModuleName   = "welcomeDB"
val testModuleName = "welcomeTest"

dependencies {

}

val webapp = project(":webapp");

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(buildDir)
}

tasks.register("build") {
    group       = "Build"
    description = "Build server modules"

    dependsOn(compileAppModule)
}

val compileAppModule = tasks.register("compileAppModule") {
    group       = "Build"
    description = "Compile $appModuleName module"

    dependsOn(compileDbModule)
    dependsOn(webapp.tasks["build"])

    // Copy all the web app stuff into the resources.

    doLast {
        val srcModule   = "$projectDir/main/x/$appModuleName.x"
        val resourceDir = "$projectDir/main/resources"
        val libDir      = "$buildDir"

        val src  = file("$srcModule").lastModified()
        val rsrc = fileTree("$resourceDir").getFiles().stream().
                mapToLong({f -> f.lastModified()}).max().orElse(0)
        val dest = file("$libDir/$appModuleName.xtc").lastModified()

        if (src > dest || rsrc > dest) {
            project.exec {
                commandLine("xtc", "-verbose", "-rebuild",
                            "-o", "$libDir",
                            "-L", "$libDir",
                            "$srcModule")
            }
        }
        else {
            println("$libDir/$appModuleName.xtc is up to date")
            }
    }
}

val compileDbModule = tasks.register("compileDbModule") {
    group       = "Build"
    description = "Compile $dbModuleName database module"

    val srcModule = "${projectDir}/main/x/$dbModuleName.x"
    val libDir    = "$buildDir"

    val src  = file("$srcModule").lastModified()
    val dest = file("$libDir/$dbModuleName.xtc").lastModified()

    if (src > dest) {
        project.exec {
            commandLine("xtc", "-verbose",
                        "-o", "$libDir",
                        "$srcModule")
        }
    }
    else {
        println("$libDir/$dbModuleName.xtc is up to date")
        }
}

val compileTest = tasks.register("compileTest") {
    group        = "Build"
    description  = "Compile $testModuleName module"

    dependsOn(compileDbModule)

    doLast {
        val srcModule = "$projectDir/main/x/$testModuleName.x"
        val libDir    = "$buildDir"

        val src  = file("$srcModule").lastModified()
        val dest = file("$libDir/$testModuleName.xtc").lastModified()

        if (src > dest) {
            project.exec {
                commandLine("xtc",
                            "-o", "$libDir",
                            "-L", "$libDir",
                            "$srcModule")
            }
        }
    }
}

tasks.register("runTest") {
    group       = "Run"
    description = "Run the standalone test"

    dependsOn(compileTest)

    doLast {
        val libDir = "$buildDir"

        project.exec {
            commandLine("xec",
                        "-L", "$libDir",
                        "$libDir/$testModuleName.xtc")
        }
    }
}