/*
 * Chess web application module (chess).
 *
 * Depends on the chessDB module for schema types and on the webapp content
 * for @StaticContent annotations.
 */

import org.xtclang.plugin.tasks.XtcCompileTask

plugins {
    id("xtc-conventions")
    id("webapp-conventions")
}

dependencies {
    xtcModule(project(":db"))
}

// Tests excluded from compilation pending design decisions. Each references
// APIs that either don't exist on the current source (e.g. ChessLogic.applyMove,
// ChessLogic.createMoveNotation, CheckDetection.getAllLegalMoves,
// ApiState.sessionId, OnlineGame[] indexing, String.contains) or exercise an
// injection pattern the XTC compiler currently rejects (TimeControlService is
// a service class, not an interface or const). ChessGameManagement.x is a
// @TerminalApp CLI tool misfiled under test/ and has pre-existing lexer errors
// on its JSON template strings; it should be relocated separately.
tasks.named<XtcCompileTask>("compileTestXtc") {
    exclude(
        "ChessGameManagement.x",
        "ChessApiHelperTest.x",
        "ChessOnlineLogicTest.x",
        "ChessCheckDetectionTest.x",
        "ChessSpecialMovesTest.x",
        "ChessGameInitTest.x",
        "ChessTimeControlTest.x",
    )
}
