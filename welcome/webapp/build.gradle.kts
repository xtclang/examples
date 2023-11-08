/*
 * Build the "webapp" content.
 */

val webContent = "${projectDir}/build"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(webContent)
}

tasks.register("build") {
    group       = "Build"
    description = "Build the webapp content"

    val src1 = fileTree("$projectDir/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val src2 = fileTree("$projectDir/public").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dest = fileTree("$webContent").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (src1 > dest || src2 > dest) {
        dependsOn(buildContent)
        }
    else {
        println("$webContent is up to date")
        }
}

val buildContent = tasks.register("buildContent") {
    project.exec {
        workingDir(projectDir)
        commandLine("npm", "run", "build")
    }
}