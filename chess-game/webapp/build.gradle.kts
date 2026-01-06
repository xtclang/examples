/*
 * Build the webapp content.
 */

tasks.register("build") {
    group       = "Build"
    description = "Build (copy) webapp content"

    // For now, the client is static HTML in /client, so nothing to build here
    doLast {
        println("Client HTML is served from /client directory")
    }
}
