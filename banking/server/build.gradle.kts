/*
 * Build the "server" modules.
 */
val appModuleName = "BankStressTest"
val dbModuleName  = "Bank"

val webApp   = project(":webapp")
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
}

tasks.register<Exec>("compileAppModule") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule   = "$projectDir/main/x/$appModuleName.x"
    val resourceDir = "${webApp.projectDir}"

    dependsOn("compileDbModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, "-r", resourceDir, srcModule)
}

tasks.register<Exec>("compileDbModule") {
    val srcModule = "${projectDir}/main/x/$dbModuleName.x"

    commandLine("xcc", "--verbose", "-o", buildDir, srcModule)
}