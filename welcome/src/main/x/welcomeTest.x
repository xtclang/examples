/**
 * A simple console-based database test for the welcome example.
 *
 * Run via Gradle:
 *   ./gradlew runXtc -PmoduleName=welcomeTest
 *
 * Or directly:
 *   xtc run -L build/install/examples/lib welcomeTest
 */
module welcomeTest {
    package jsondb import jsondb.xtclang.org;
    package db import welcomeDB.examples.org;

    import db.WelcomeSchema;

    void run() {
        @Inject Console console;
        @Inject Directory curDir;

        Directory dataDir  = curDir.dirFor("data").ensure();
        Directory buildDir = curDir.dirFor("build").ensure();

        using (WelcomeSchema schema =
                jsondb.createConnection(db.qualifiedName, dataDir, buildDir).as(WelcomeSchema)) {
            String guest = "test-guest";
            Int    count = schema.counters.getOrDefault(guest, 0);
            schema.counters.put(guest, ++count);
            console.print($"Welcome! You are guest #{guest}, visit #{count}");
        }
    }
}
