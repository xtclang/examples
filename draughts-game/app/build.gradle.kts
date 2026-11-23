/*
 * Draughts web application module (draughts).
 *
 * Depends on the draughtsDB module for schema types and on the webapp content
 * for @StaticContent annotations.
 */

plugins {
    id("xtc-conventions")
    id("webapp-conventions")
}

dependencies {
    xtcModule(project(":db"))
}
