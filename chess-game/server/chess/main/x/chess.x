/**
 * Chess Game Server Module
 * 
 * This module implements a web-based chess game server using the XTC web framework.
 * It provides a RESTful API for managing chess games with both single-player (vs AI)
 * and online two-player multiplayer modes.
 * 
 * Key features:
 * - Turn-based chess gameplay with simplified rules (no castling, en-passant, or check detection)
 * - Single-player mode with automated opponent (Black player) with AI-driven move selection
 * - Online multiplayer mode with room-based matchmaking
 * - Game state persistence using the chess database schema
 * - RESTful API endpoints for moves, game state, room management, and game reset
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
    import db.GameRecord;
    import db.GameMode;
    import db.GameStatus;
    import db.Color;
    import db.OnlineGame;

    /**
     * Home Service
     * 
     * Serves the static web client (HTML, CSS, JavaScript) for the chess game.
     * All requests to the root path "/" are served with the index.html file
     * from the public directory.
     */
    @StaticContent("/", /public/index.html)
    service Home {}

}
