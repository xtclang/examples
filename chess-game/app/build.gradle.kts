/*
 * Chess web application module (chess).
 *
 * Depends on the chessDB module for schema types and on the webapp content
 * for @StaticContent annotations.
 *
 * Note: chess-game/app/cli/ChessGameManagement.x is a @TerminalApp CLI tool
 * that lives outside any XTC source set; it has pre-existing lexer errors
 * in its $|...| JSON template strings and needs to be relocated into its
 * own module — tracked in xtclang/examples#14.
 */

plugins {
    id("xtc-conventions")
    id("webapp-conventions")
}

dependencies {
    xtcModule(project(":db"))
}
