import webcli.*;

/**
 * Time-control game creation commands.
 *
 * Wraps the standard reset / create endpoints with a JSON body that
 * configures the clock for each player (milliseconds + increment).
 */
mixin TimedGameCommands {

    /**
     * Start a timed single-player game (e.g. 5 minutes + 3 s increment).
     */
    @Command("new-timed-game", "Start a timed game (sessionId timeMs incrementMs)")
    String newTimedGame(String sessionId, String timeMs, String incrementMs) =
        post($|api/reset/{sessionId}
            , $|\{"timeControlMs":{timeMs},"incrementMs":{incrementMs}\}
            );

    /**
     * Create an online room with time control.
     */
    @Command("create-timed-room", "Create timed online room (timeMs incrementMs)")
    String createTimedRoom(String timeMs, String incrementMs) =
        post($|api/online/create
            , $|\{"timeControlMs":{timeMs},"incrementMs":{incrementMs}\}
            );
}
