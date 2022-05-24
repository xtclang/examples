/*
 * Build the "server" modules.
 */

val xdkExe = "${projectDir}/xdk/bin"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete("$buildDir")
}

tasks.register<Copy>("updateXdk") {

    val xdkHome = "$projectDir/xdk/"

    var xvmHome = System.getProperty("xvm.home")
    if (xvmHome == null || xvmHome == "") {
        xvmHome = "../../../xvm"
    }

    val xdkExt = "$xvmHome/xdk/build/xdk"
    val xdkLib = "$projectDir/xdk"

    val srcTimestamp = fileTree(xdkExt).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dstTimestamp = fileTree(xdkLib).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (srcTimestamp > dstTimestamp) {
        from("$xdkExt") {
            include("bin/**")
            include("javatools/**")
            include("lib/**")
        }
        into("$xdkLib")
        doLast {
            println("Finished task: updateXdk")
        }
    }
    else {
        println("Xdk is up to date")
    }
}

tasks.register("build") {
    group       = "Build"
    description = "Compile the server modules"

    dependsOn(compileWelcome)
    }

val compileWelcomeDB = tasks.register("compileWelcomeDB") {
    group       = "Build"
    description = "Compile welcome module"

    val srcModule = "${projectDir}/main/x/welcomeDB.x"
    val libDir    = "$buildDir"

    val src  = file("$srcModule").lastModified()
    val dest = file("$buildDir/welcomeDB.xtc").lastModified()

    if (src > dest) {
        project.exec {
            commandLine("$xdkExe/xtc", "-verbose",
                        "-o", "$libDir",
                        "$srcModule")
        }
    }
}

val compileWelcome = tasks.register("compileWelcome") {
    group       = "Build"
    description = "Compile welcome module"

    shouldRunAfter(compileWelcomeDB)

    val srcModule   = "${projectDir}/main/x/welcome.x"
    val resourceDir = "${projectDir}/main/resources"
    val libDir      = "$buildDir"

    val src  = file("$srcModule").lastModified()
    val rsrc = fileTree("$resourceDir").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dest = file("$buildDir/welcomeDB.xtc").lastModified()

    if (src > dest || rsrc > dest) {
        project.exec {
            commandLine("$xdkExe/xtc", "-verbose",
                        "-o", "$libDir",
                        "-L", "$libDir",
                        "$srcModule")
        }
    }
}