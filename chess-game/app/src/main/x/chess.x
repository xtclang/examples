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
 * This module implements a web-based chess game server using the XTC web framework.
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

    // Import specific web framework components
    import web.*;
    // Import database schema and models
    import db.ChessSchema;
    import db.models.GameRecord;
    import db.models.GameMode;
    import db.models.GameStatus;
    import db.models.Color;
    import db.models.OnlineGame;
    import db.models.ChatMessage;

    /**
     * Home Service
     * 
     * Serves the React/Vite web client for the chess game. The built output
     * (webapp/build) is served from the root path "/".
     */
    @StaticContent("/", /build)
    service Home {}
}
