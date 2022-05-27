/*
 * Build the "webapp" content.
 */

val webContent = "${project(":server").projectDir}/main/resources/webapp"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(buildDir)
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
        dependsOn(copyContent)
        }
    else {
        println("$webContent is up to date")
        }
}

val copyContent = tasks.register("copyContent") {
    project.exec {
        workingDir(projectDir)
        commandLine("npm", "run", "build")
    }

    doLast {
        println("Copying static content from $buildDir to $webContent")

        copy {
            from(buildDir)
            into(webContent)
        }
    }
}