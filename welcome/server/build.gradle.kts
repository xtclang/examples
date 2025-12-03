/*
 * Build the "server" modules.
 */

val appModuleName  = "welcome"
val dbModuleName   = "welcomeDB"
val testModuleName = "welcomeTest"
val cliModuleName  = "welcomeCLI"

val webApp   = project(":webapp");
val buildDir = layout.buildDirectory.get()

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(buildDir)
}

tasks.register("build") {
    group       = "Build"
    description = "Build server modules"

    dependsOn("compileAppModule")
    dependsOn("compileCLI")
}

tasks.register<Exec>("compileAppModule") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule   = "$projectDir/main/x/$appModuleName.x"
    val resourceDir = "${webApp.projectDir}"

    dependsOn("compileDbModule")
    dependsOn(webApp.tasks["build"])

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, "-r", resourceDir, srcModule)
}

tasks.register<Exec>("compileDbModule") {
    val srcModule = "${projectDir}/main/x/$dbModuleName.x"

    commandLine("xcc", "--verbose", "-o", buildDir, srcModule)
}

tasks.register<Exec>("compileTest") {
    val srcModule = "$projectDir/main/x/$testModuleName.x"

    dependsOn("compileDbModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("compileCLI") {
    val srcModule = "${projectDir}/main/x/$cliModuleName.x"

    dependsOn("compileDbModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("runTest") {
    val srcModule = "${projectDir}/main/x/$cliModuleName.x"

    dependsOn("compileTest")

    commandLine("xec", "-L", buildDir, "$buildDir/$testModuleName.xtc")
}
