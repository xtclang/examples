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
    package jsondb import jsondb.xtclang.org;        // Opens the database when not hosted

    // Import specific web framework components
    import web.*;
    // Import database schema and models
    import db.ChessSchema;
    import db.models.GameRecord;
    import db.models.GameMode;
    import db.models.GameStatus;
    import db.models.Color;
    import db.models.OnlineGame;

    /**
     * Database access for the web services.
     *
     * When a host runs this application it supplies the schema by injection, and that is what the
     * services get. Without a host -- e.g. a test invoking a service directly -- the injection
     * yields Null, and this opens the `chessDB` module over `jsondb` instead, so the services work
     * with nothing but the two compiled modules and a directory to write to.
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
     * Home Service
     * 
     * Serves the React/Vite web client for the chess game. The built output
     * (webapp/build) is served from the root path "/".
     */
    @StaticContent("/", /)
    service Home {}
}
