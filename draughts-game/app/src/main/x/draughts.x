import core.DraughtsRules;
import core.DraughtsGame;
import core.DraughtsAi;
import api.DraughtsApi;

/**
 * Draughts Game Server Module
 *
 * A web-based draughts (English draughts / checkers) game, written with the Ecstasy web
 * framework: play the computer at one of three levels, or a second person at the same screen. It
 * is a port of the Compator draughts course demo.
 *
 * Key features:
 * - The full rules of English draughts, enforced on the server: compulsory captures, multiple
 *   jumps, kings, and a draw rule (see draughts/core/DraughtsRules.x)
 * - One game per browser session, persisted in the draughts database schema
 * - A computer opponent (minimax with alpha-beta pruning) at Low, Medium and High strength
 * - A daily scoreboard of nicknames, kept by the server when a game ends
 * - Static content serving for the React client
 */
@WebApp
module draughts.examples.org {
    // Package imports: organize dependencies from different modules
    package db     import draughtsDB.examples.org;   // Database schema and data models
    package web    import web.xtclang.org;           // Web framework for HTTP handling
    package jsondb import jsondb.xtclang.org;        // Opens the database when not hosted

    import web.*;
    import db.DraughtsSchema;
    import db.models.GameRecord;
    import db.models.GameStatus;
    import db.models.Color;
    import db.models.MoveEntry;
    import db.models.ScoreEntry;

    /**
     * Database access for the web services.
     *
     * When a host runs this application it supplies the schema by injection, and that is what the
     * services get. Without a host -- e.g. a test invoking a service directly -- the injection
     * yields Null, and this opens the `draughtsDB` module over `jsondb` instead, so the services
     * work with nothing but the two compiled modules and a directory to write to.
     */
    static service Database {
        /**
         * Where the database files are kept, relative to the working directory.
         */
        static String DATA_DIR = "data/draughtsDB";

        /**
         * Where the generated database host module is written, relative to the working directory.
         */
        static String BUILD_DIR = "build/db";

        static String DB_MODULE = "draughtsDB.examples.org";

        /**
         * The open database. Created once, however many connections are handed out.
         */
        @Lazy jsondb.Catalog catalog.calc() {
            @Inject Directory curDir;
            return jsondb.createCatalog(DB_MODULE,
                                        curDir.dirFor(DATA_DIR).ensure(),
                                        curDir.dirFor(BUILD_DIR).ensure());
        }

        /**
         * A connection for one caller. Each web service holds its own, so that two requests are
         * never sharing a transaction.
         */
        DraughtsSchema connect() {
            if (DraughtsSchema hosted := hostedSchema()) {
                return hosted;
            }
            return catalog.createConnection().as(DraughtsSchema);
        }

        /**
         * The schema a host injects, under the name "schema".
         *
         * Containers disagree on how to report a resource they do not have: the top-level one
         * `xec` creates yields Null for a nullable injection, while a nested one -- the test
         * runner, or a platform hosting several apps -- throws. Both mean "not hosted".
         */
        private conditional DraughtsSchema hostedSchema() {
            try {
                @Inject(resourceName="schema") DraughtsSchema? schema;
                if (schema != Null) {
                    return True, schema;
                }
            } catch (Exception notHosted) {}
            return False;
        }
    }

    /**
     * Home Service
     *
     * Serves the React/Vite web client. The built output (webapp/build) is served from "/".
     */
    @StaticContent("/", /)
    service Home {}
}
