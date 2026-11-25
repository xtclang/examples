import core.DraughtsGame;
import api.DraughtsApi.ApiState;

/**
 * SessionHelper - what the single-player endpoints share: finding a session's game, putting its
 * result on the scoreboard, and describing it for the client.
 */
service SessionHelper {
    /**
     * The game for a session, created in the starting position if there is none.
     */
    static GameRecord ensureGame(DraughtsSchema schema, String sessionId) {
        if (GameRecord game := schema.games.get(sessionId)) {
            return game;
        }
        GameRecord fresh = DraughtsGame.newGame();
        schema.games.put(sessionId, fresh);
        return fresh;
    }

    /**
     * Put a finished game on the session's scoreboard, one result for each player.
     */
    static void recordResult(DraughtsSchema schema, String sessionId, GameRecord game) {
        Scoreboard.record(schema, Scoreboard.sessionScope(sessionId), game);
    }

    /**
     * Converts a GameRecord to the API response format.
     */
    static ApiState toApiState(GameRecord game, String? message = Null, String sessionId = "") {
        Boolean ongoing     = game.status == Ongoing;
        Boolean mustCapture = ongoing
                && DraughtsRules.legalMoves(game.board, game.turn)[0].captures.size > 0;
        return new ApiState(
                DraughtsGame.boardRows(game.board),
                game.turn.toString(),
                game.status.toString(),
                message ?: DraughtsGame.describeState(game, mustCapture),
                game.lastMove,
                game.blackName,
                game.whiteName,
                DraughtsRules.countPieces(game.board, Black),
                DraughtsRules.countPieces(game.board, White),
                mustCapture,
                game.history,
                sessionId,
                game.level,
                DraughtsGame.computerToMove(game));
    }
}
