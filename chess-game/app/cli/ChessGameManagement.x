/**
 * Chess Game Management CLI - Functional test tool.
 *
 * Exercises all chess REST API endpoints (single-player, online multiplayer, chat)
 * from the command line using the `@TerminalApp` / `@Command` pattern.
 *
 * Usage:
 *   - Launch while the chess-game web app is running.
 *   - Type a command at the prompt (e.g. "new-game", "move e2 e4").
 *
 * Endpoint mapping:
 *   ChessApi        -> /api/...
 *   OnlineChessApi  -> /api/online/...
 *   ChatApi         -> /api/chat/...
 *
 * Commands are organised into five mixins:
 *   - SinglePlayerCommands : single-player game operations and edge-case tests
 *   - OnlineCommands       : online multiplayer room management and flows
 *   - ChatCommands         : in-game chat and bulk message tests
 *   - TimedGameCommands    : time-control game creation
 *   - GameFlowCommands     : scripted multi-move game sequences
 */
@TerminalApp("Chess Game Management CLI", "Chess>")
module ChessGameManagement.examples.org {
    package webcli import webcli.xtclang.org;
    import webcli.*;

    incorporate SinglePlayerCommands;
    incorporate OnlineCommands;
    incorporate ChatCommands;
    incorporate TimedGameCommands;
    incorporate GameFlowCommands;
}
