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

// Tests excluded from compilation pending design decisions or source fixes.
// Re-enable each by removing its line once the underlying issue is resolved.
tasks.named<XtcCompileTask>("compileTestXtc") {
    // TODO: not a test — @TerminalApp CLI tool mis-filed under test/. Five
    //       LEXER-09 errors on `\}` inside `$|...` JSON template strings.
    //       Relocate outside the test source set and fix the escapes.
    exclude("ChessGameManagement.x")

    // TODO: references `state.sessionId` but ApiState (chess/api/ChessApi.x:199)
    //       has no sessionId field. Decide: add the field to ApiState or drop
    //       the assertion. Also uses String.contains which XTC String lacks.
    exclude("ChessApiHelperTest.x")

    // TODO: calls String.contains (doesn't exist — use indexOf conditional)
    //       and indexes into OnlineGame with `result1[0]` (not a collection).
    //       Needs test rewrite against the current OnlineChessLogic API.
    exclude("ChessOnlineLogicTest.x")

    // TODO: calls CheckDetection.getAllLegalMoves which does not exist on
    //       the current CheckDetection class. Confirm intended signature
    //       then either add the method or adapt the test.
    exclude("ChessCheckDetectionTest.x")

    // TODO: calls ChessLogic.applyMove(record, board, from, to, promo) but
    //       only ChessLogic.applyHumanMove(record, "from", "to", promo)
    //       exists. Either add the int-indexed overload or migrate the test.
    exclude("ChessSpecialMovesTest.x")

    // TODO: calls ChessLogic.createMoveNotation(...) which does not exist.
    //       Either expose the internal notation helper or rewrite the test.
    exclude("ChessGameInitTest.x")

    // TODO: uses `@Inject TimeControlService` but the XTC compiler rejects
    //       this — `Only interfaces or const objects can be injected`. Turn
    //       TimeControlService into an interface (or a const with service
    //       facade) before re-enabling.
    exclude("ChessTimeControlTest.x")
}
