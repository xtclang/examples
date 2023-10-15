import org.gradle.language.base.plugins.LifecycleBasePlugin.BUILD_GROUP
import org.gradle.language.base.plugins.LifecycleBasePlugin.BUILD_TASK_NAME

/*
 * Build the "server" modules.
 */

plugins {
    base
}

val appModuleName  = "welcome"
val dbModuleName   = "welcomeDB"
val testModuleName = "welcomeTest"

val webapp = project(":webapp")
val buildDir = layout.buildDirectory

tasks.named(BUILD_TASK_NAME) {
    group       = "Build"
    description = "Build server modules"
    dependsOn(compileAppModule)
}

val compileAppModule by tasks.registering {
    group       = "Build"
    description = "Compile $appModuleName module"

    dependsOn(compileDbModule)
    dependsOn(webapp.tasks["build"])

    // Copy all the web app stuff into the resources.
    val srcModule   = "$projectDir/main/x/$appModuleName.x"
    val resourceDir = "$projectDir/main/resources"
    val libDir      = "$buildDir"

    val src  = file(srcModule).lastModified()
    val rsrc = fileTree(resourceDir).files.stream().mapToLong(File::lastModified).max().orElse(0)
    val dest = file("$libDir/$appModuleName.xtc").lastModified()
    onlyIf {
        val updates = src > dest || rsrc > dest
        if (!updates) {
            println("$libDir/$appModuleName.xtc is up to date")
        }
        updates
    }
    doLast {
        exec {
            commandLine("xtc", "-verbose", "-rebuild", "-o", libDir, "-L", libDir, srcModule)
        }
    }
}

val compileDbModule = tasks.register("compileDbModule") {
    group       = BUILD_GROUP
    description = "Compile $dbModuleName database module"

    val srcModule = "${projectDir}/main/x/$dbModuleName.x"
    val libDir    = "$buildDir"
    val src  = file(srcModule).lastModified()
    val dest = file("$libDir/$dbModuleName.xtc").lastModified()
    onlyIf {
        src > dest
    }
    exec {
        commandLine("xtc", "-verbose", "-o", libDir, srcModule)
    }
}

val compileTest = tasks.register("compileTest") {
    group       = BUILD_GROUP
    description  = "Compile $testModuleName module"

    dependsOn(compileDbModule)

    doLast {
        val srcModule = "$projectDir/main/x/$testModuleName.x"
        val libDir    = "$buildDir"
        val src  = file(srcModule).lastModified()
        val dest = file("$libDir/$testModuleName.xtc").lastModified()
        onlyIf {
            src > dest
        }
        exec {
            commandLine("xtc", "-o", libDir, "-L", libDir, srcModule)
        }
    }
}

tasks.register("runTest") {
    group       = "application"
    description = "Run the standalone test"
    dependsOn(compileTest)
    doLast {
        val libDir = buildDir
        exec {
            commandLine("xec", "-L", libDir, "$libDir/$testModuleName.xtc")
        }
    }
}
