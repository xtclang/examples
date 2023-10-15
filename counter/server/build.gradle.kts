/*
 * Build the "server" modules.
 */

val appModuleName = "count"
val dbModuleName = "countDB"

val webapp = project(":webapp");

tasks.register("clean") {
    group = "Build"
    description = "Delete previous build results"

    delete(buildDir)
}

tasks.register("build") {
    group = "Build"
    description = "Build server modules"

    dependsOn(compileAppModule)
}

val compileAppModule = tasks.register("compileAppModule") {
    group = "Build"
    description = "Compile $appModuleName module"

    dependsOn(compileDbModule)
    dependsOn(webapp.tasks["build"])

    doLast {
        val srcModule = "$projectDir/main/x/$appModuleName.x"
        val resourceDir = "$projectDir/main/resources"
        val libDir = "$buildDir"

        val src = file("$srcModule").lastModified()
        val rsrc = fileTree("$resourceDir").getFiles().stream().mapToLong({ f -> f.lastModified() }).max().orElse(0)
        val dest = file("$libDir/$appModuleName.xtc").lastModified()

        if (src > dest || rsrc > dest) {
            exec {
                commandLine(
                    "xtc", "-verbose", "-rebuild",
                    "-o", "$libDir",
                    "-L", "$libDir",
                    "$srcModule"
                )
            }
        } else {
            println("$libDir/$appModuleName.xtc is up to date")
        }
    }
}

val compileDbModule = tasks.register("compileDbModule") {
    group = "Build"
    description = "Compile $dbModuleName database module"

    val srcModule = "${projectDir}/main/x/$dbModuleName.x"
    val libDir = "$buildDir"
    doLast {
        val src = file("$srcModule").lastModified()
        val dest = file("$libDir/$dbModuleName.xtc").lastModified()
        exec {
            onlyIf {
                src > dest
            }
            commandLine("xtc", "-verbose", "-o", libDir, srcModule)
        }
    }
}
