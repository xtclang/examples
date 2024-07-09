/*
 * Build the "server" modules.
 */

val appModuleName  = "welcome"
val dbModuleName   = "welcomeDB"
val testModuleName = "welcomeTest"
val cliModuleName  = "welcomeCLI"

val webapp   = project(":webapp");
val buildDir = layout.buildDirectory.get()

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(buildDir)
}

tasks.register("build") {
    group       = "Build"
    description = "Build server modules"

    dependsOn(compileAppModule)
    dependsOn(compileCLI)
}

val compileAppModule = tasks.register("compileAppModule") {
    group       = "Build"
    description = "Compile $appModuleName module"

    dependsOn(compileDbModule)
    dependsOn(webapp.tasks["build"])

    doLast {
        val srcModule   = "$projectDir/main/x/$appModuleName.x"
        val resourceDir = "${webapp.projectDir}"

        project.exec {
            commandLine("xcc", "--verbose",
                        "-o", buildDir,
                        "-L", buildDir,
                        "-r", resourceDir,
                        srcModule)
        }
    }
}

val compileDbModule = tasks.register("compileDbModule") {
    group       = "Build"
    description = "Compile $dbModuleName database module"

    val srcModule = "${projectDir}/main/x/$dbModuleName.x"

    project.exec {
        commandLine("xcc", "--verbose",
                    "-o", buildDir,
                    srcModule)
    }
}

val compileTest = tasks.register("compileTest") {
    group        = "Build"
    description  = "Compile $testModuleName module"

    dependsOn(compileDbModule)

    doLast {
        val srcModule = "$projectDir/main/x/$testModuleName.x"

        project.exec {
            commandLine("xcc",
                        "-o", buildDir,
                        "-L", buildDir,
                        srcModule)
        }
    }
}

val compileCLI = tasks.register("compileCLI") {
    group        = "Build"
    description  = "Compile $cliModuleName module"

    doLast {
        val srcModule = "$projectDir/main/x/$cliModuleName.x"

        project.exec {
            commandLine("xcc",
                        "-o", buildDir,
                        "-L", buildDir,
                        srcModule)
        }
    }
}

tasks.register("runTest") {
    group       = "Run"
    description = "Run the standalone test"

    dependsOn(compileTest)

    doLast {
        project.exec {
            commandLine("xec",
                        "-L", "$buildDir",
                        "$buildDir/$testModuleName.xtc")
        }
    }
}