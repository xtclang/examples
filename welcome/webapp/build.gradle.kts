import java.io.ByteArrayOutputStream

/*
 * Build the "webapp" content.
 */
plugins {
    base
    id("com.github.node-gradle.node").version("7.0.1")
}

node {
    // node version
    version = "18.18.0"
    // npm version
    npmVersion = "10.2.0"
}

val webContent = "${project(":server").projectDir}/src/main/resources/webapp"
val buildDir = layout.buildDirectory


// Webapp:   src, public, from this project
// web contents from server/projectdir/(src/main/resources /webapp.
// That's not seupposed to be there.
/*
tasks.named("build").configure {
    description = "Build the webapp content"
    dependsOn(copyContent)
    val src1 = fileTree("$projectDir/src").files.stream().mapToLong(File::lastModified).max().orElse(0)
    val src2 = fileTree("$projectDir/public").files.stream().mapToLong(File::lastModified).max().orElse(0)
    val dest = fileTree("$webContent").files.stream().mapToLong(File::lastModified).max().orElse(0)
    onlyIf {
        src1 > dest || src2 > dest
    }
}
*/
fun executeRawCommand(cmd: String): String? {
    println("Executing: $cmd")
    ProcessBuilder(cmd.split(" ")).start().apply { waitFor() }.inputStream.bufferedReader().use { return it.readText().trim().ifEmpty { null } }
}

val npmInstall by tasks.named("npmInstall")

val copyContent by tasks.registering {
    dependsOn(npmInstall)

    logger.lifecycle("node workDir: ${node.workDir.get().asFile.absolutePath}")
    logger.lifecycle("npm  workDir: ${node.npmWorkDir.get().asFile.absolutePath}")
    logger.lifecycle("npm  command: ${node.npmCommand.get()}")

    doLast {
        val whichNpm = executeRawCommand("which npm")
        logger.lifecycle("Using npm executable: $whichNpm")

        val stdout = ByteArrayOutputStream()
        val stderr = ByteArrayOutputStream()
        exec {
            standardOutput = stdout
            errorOutput = stderr
            workingDir(projectDir)
            commandLine("npm", "run", "build")
        }
        stdout.toString().lines().forEach { line ->
            logger.lifecycle("[stdout] $line")
        }
        stderr.toString().lines().forEach { line ->
            logger.lifecycle("[stderr] $line")
        }

        logger.lifecycle("Copying static content from ${layout.buildDirectory.get()}to $webContent")
        copy {
            from(layout.buildDirectory)
            into(webContent)
        }
    }
}

