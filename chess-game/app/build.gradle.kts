/*
 * Chess web application module (chess).
 *
 * Depends on the chessDB module for schema types and on the webapp content
 * for @StaticContent annotations.
 */

plugins {
    id("xtc-conventions")
    id("webapp-conventions")
}

dependencies {
    xtcModule(project(":db"))
}
