/**
 * This is a simple console-based db test.
 */
module welcomeTest
    {
    package jsondb import jsondb.xtclang.org;
    package db import welcomeDB;

    import db.WelcomeSchema;

    void run()
        {
        @Inject Console console;
        @Inject Directory curDir;

        Directory dataDir  = curDir.dirFor("data").ensure();
        Directory buildDir = curDir.dirFor("build").ensure();

        using (WelcomeSchema schema =
                jsondb.createConnection("welcomeDB", dataDir, buildDir).as(WelcomeSchema))
            {
            console.println($"Welcome! You are guest #{schema.count.next()}");
            }
        }
    }