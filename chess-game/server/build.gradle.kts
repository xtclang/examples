/*
 * Build the "server" modules.
 */

val appModuleName   = "chess"
val dbModuleName    = "chessDB"
val logicModuleName = "chessLogic"

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
}

tasks.register<Exec>("compileAppModule") {
    val libDir      = "${rootProject.projectDir}/lib"
    val srcModule   = "$projectDir/main/x/$appModuleName.x"
    val resourceDir = "${webApp.projectDir}"

    dependsOn("compileDbModule", "compileLogicModule", "compileOnlineChessModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, "-r", resourceDir, srcModule)
}

tasks.register<Exec>("compileDbModule") {
    val srcModule = "${projectDir}/main/x/$dbModuleName.x"

    commandLine("xcc", "--verbose", "-o", buildDir, srcModule)
}

// Compile chess sub-modules (ChessBoard, ChessPieces, ChessAI, ChessGame)
tasks.register<Exec>("compileChessBoardModule") {
    val srcModule = "${projectDir}/main/x/ChessBoard.x"

    dependsOn("compileDbModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("compileChessPiecesModule") {
    val srcModule = "${projectDir}/main/x/ChessPieces.x"

    dependsOn("compileChessBoardModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("compileChessAIModule") {
    val srcModule = "${projectDir}/main/x/ChessAI.x"

    dependsOn("compileChessBoardModule", "compileChessPiecesModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("compileChessGameModule") {
    val srcModule = "${projectDir}/main/x/ChessGame.x"

    dependsOn("compileChessBoardModule", "compileChessPiecesModule", "compileChessAIModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("compileLogicModule") {
    val srcModule = "${projectDir}/main/x/$logicModuleName.x"

    dependsOn("compileChessGameModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}

tasks.register<Exec>("compileOnlineChessModule") {
    val srcModule = "${projectDir}/main/x/OnlineChess.x"

    dependsOn("compileLogicModule")

    commandLine("xcc", "--verbose", "-o", buildDir, "-L", buildDir, srcModule)
}
