/**
 * Convention plugin for XTC modules with static webapp content.
 *
 * Adds the project's webapp/ directory as a resource source, so that
 * @StaticContent annotations can reference paths like /public/index.html.
 */

plugins {
    id("org.xtclang.xtc-plugin")
}

sourceSets {
    main {
        resources {
            srcDir("webapp")
        }
    }
}
