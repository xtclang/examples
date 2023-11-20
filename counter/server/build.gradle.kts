/*
 * Build the "server" modules.
 */

val appModuleName = "count"
val dbModuleName  = "countDB"

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
}

val compileAppModule = tasks.register("compileAppModule") {
    group       = "Build"
    description = "Compile $appModuleName module"

    dependsOn(compileDbModule)

    doLast {
        val srcModule   = "$projectDir/main/x/$appModuleName.x"
        val resourceDir = "${webapp.projectDir}"

        project.exec {
            commandLine("xcc", "-verbose",
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
        commandLine("xcc", "-verbose",
                    "-o", buildDir,
                    srcModule)
    }
}