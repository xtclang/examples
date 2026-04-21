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

// ChessGameManagement.x has been moved out of src/test/x to
// chess-game/app/cli/ — it's a @TerminalApp CLI tool, not a test, and has
// pre-existing LEXER-09 errors on `\}` inside $|...| JSON template strings.
// The cli/ directory is outside any XTC source set, so nothing compiles it
// automatically. Follow-up work: fix the lexer escapes and wire it up as a
// runnable module (probably its own :cli subproject or a standalone .xtc
// artifact). Tracked in TODO above.
