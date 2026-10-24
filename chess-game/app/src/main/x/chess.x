import utils.BoardUtils;
import utils.BoardOperations;
import utils.DirectionUtils;
import validation.PieceValidator;
import validation.CheckDetection;
import validation.MoveValidator;
import validation.ValidMovesHelper;
import config.CastlingManager;
import core.ChessLogic;
import core.OnlineChessLogic;
import ai.ChessAPIClient;
import ai.StockfishApi;
/**
 * Chess Game Server Module
 * 
 * This module implements a web-based chess game server using the Ecstasy web framework.
 * It provides a RESTful API for managing chess games with both single-player (vs AI)
 * and online two-player multiplayer modes.
 * 
 * Key features:
 * - Turn-based chess gameplay with simplified rules (no castling, en-passant, or check detection)
 * - Single-player mode whose opponent (Black) plays the moves returned by the Stockfish Online
 *   engine API; no move is chosen locally except as an offline fallback
 * - Online multiplayer mode with room-based matchmaking
 * - Game state persistence using the chess database schema
 * - RESTful API endpoints for moves, game state, room management, and game reset
 * - An engine proxy (/api/engine) so the web client can read the same evaluations the
 *   computer plays by
 * - Static content serving for the web client interface
 */
@WebApp
module chess.examples.org {
    // Package imports: organize dependencies from different modules
    package db     import chessDB.examples.org;      // Database schema and data models
    package web    import web.xtclang.org;           // Web framework for HTTP handling
    package xenia  import xenia.xtclang.org;         // HTTP server that hosts this web app
    package jsondb import jsondb.xtclang.org;        // Opens the database when run standalone

    // Import specific web framework components
    import web.*;
    import web.http.HostInfo;
    // Import database schema and models
    import db.ChessSchema;
    import db.models.GameRecord;
    import db.models.GameMode;
    import db.models.GameStatus;
    import db.models.Color;
    import db.models.OnlineGame;
    import db.models.ChatMessage;

    /**
     * Starts the HTTP server and blocks until the process is stopped.
     *
     *     xec -L <module path> chess.xtc                         # localhost:8080 / 8090
     *     xec -L <module path> chess.xtc localhost:3000/3001     # different ports
     *     xec -L <module path> chess.xtc myhost:8080/8090 0.0.0.0:8080/8090
     *
     * The first argument is the address clients use: it is matched against the `Host` header and
     * is the name the TLS certificate is issued for. The second is the socket to listen on, for
     * when the two differ -- binding to `0.0.0.0` to reach the server from another machine, or
     * sitting behind port forwarding, a reverse proxy, or a container.
     *
     * The route has to be a host *name*, not an IP address, for HTTPS to work: the server picks
     * its certificate by the name the client sends in the TLS handshake, and a client connecting
     * to a bare IP sends none.
     *
     * @param args  an optional "host:httpPort/httpsPort" to serve on, and an optional second one
     *              to bind to when it differs from the address clients use
     */
    void run(String[] args = []) {
        HostInfo route   = hostOf(args.size > 0 ? args[0] : DEFAULT_ADDRESS);
        HostInfo binding = hostOf(args.size > 1 ? args[1] : args.size > 0 ? args[0]
                                                                         : DEFAULT_ADDRESS);

        xenia.createServer(this, route=route, binding=binding);

        @Inject Console console;
        console.print($|Chess server listening on:
                       |
                       |    https://{route.host}:{route.httpsPort}/   <- open this one
                       |    http://{route.host}:{route.httpPort}/
                       |
                       |Every web service is @HttpsRequired, so the HTTP port answers an API call
                       |with a redirect rather than data; open the HTTPS URL and accept the
                       |self-signed certificate the server generates on first run.
                       |
                       |The REST API is under /api, and the engine proxy under /api/engine.
                       |Use Ctrl-C to stop.
                     );
    }

    /**
     * The address served when none is given on the command line.
     */
    static String DEFAULT_ADDRESS = "localhost:8080/8090";

    /**
     * Database access for the web services.
     *
     * When a host runs this application it supplies the schema by injection, and that is what the
     * services get. Run standalone -- `xec chess.xtc` -- there is no host, the injection yields
     * Null, and this opens the `chessDB` module over `jsondb` instead, so the server works with
     * nothing but the two compiled modules and a directory to write to.
     */
    static service Database {
        /**
         * Where the database files are kept, relative to the working directory.
         */
        static String DATA_DIR = "data/chessDB";

        /**
         * Where the generated database host module is written, relative to the working directory.
         */
        static String BUILD_DIR = "build/db";

        static String DB_MODULE = "chessDB.examples.org";

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
        ChessSchema connect() {
            if (ChessSchema hosted := hostedSchema()) {
                return hosted;
            }
            return catalog.createConnection().as(ChessSchema);
        }

        /**
         * The schema a host injects, under the name "schema" that the web services have always
         * asked for.
         *
         * Containers disagree on how to report a resource they do not have: the top-level one
         * `xec` creates yields Null for a nullable injection, while a nested one -- the test
         * runner, or a platform hosting several apps -- throws. Both mean "not hosted".
         */
        private conditional ChessSchema hostedSchema() {
            try {
                @Inject(resourceName="schema") ChessSchema? schema;
                if (schema != Null) {
                    return True, schema;
                }
            } catch (Exception notHosted) {}
            return False;
        }
    }

    /**
     * Parses a "host", "host:httpPort/httpsPort" address into a [HostInfo]. A bare host keeps
     * the standard ports 80 and 443.
     *
     * The host is lower-cased: a client sends the server name in the TLS handshake already
     * lower-cased, and that is matched against the route exactly, so a route spelled with any
     * capitals -- which is what `hostname` reports on a Mac -- would never be matched.
     */
    static HostInfo hostOf(String address) = new HostInfo(address.toLowercase());

    /**
     * Home Service
     * 
     * Serves the React/Vite web client for the chess game. The built output
     * (webapp/build) is served from the root path "/".
     */
    @StaticContent("/", /build)
    service Home {}
}
