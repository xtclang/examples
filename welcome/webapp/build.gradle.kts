/*
 * Build the "webapp" content.
 */

val server = project(":server")

val xdkExe = "${projectDir}/xdk/bin"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete("$buildDir")
}

tasks.register("build") {
    group       = "Build"
    description = "BUild the webapp content"

    val dirResources = "${server.projectDir}/main/resources/webapp"

    val src1 = fileTree("$projectDir/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val src2 = fileTree("$projectDir/public").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dest = fileTree("$dirResources").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (src1 > dest || src2 > dest) {
        project.exec {
            commandLine("npm",
                        "run",
                        "build")
        }

        doLast {
            println("Copying static content from $buildDir to $dirResources")
            copy {
                from("$buildDir")
                into(dirResources)
            }
        }
    }
}