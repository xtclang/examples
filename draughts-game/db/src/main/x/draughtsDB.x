/**
 * Draughts Database Schema Module
 *
 * Defines the database schema and data models for the draughts game, using the Object-Oriented
 * Database (OODB) framework to persist game state and the daily scoreboard.
 *
 * Models live in draughtsDB/models/:
 * - Color, GameStatus: who moves, and how a game stands
 * - MoveEntry, GameRecord: a game and its history
 * - ScoreEntry: one player's results for one day
 */
@oodb.Database
module draughtsDB.examples.org {
    // Import Object-Oriented Database framework
    package oodb import oodb.xtclang.org;

    import models.Color;
    import models.GameStatus;
    import models.MoveEntry;
    import models.GameRecord;
    import models.ScoreEntry;
    import models.TimeControl;
    import models.RoomRecord;

    /**
     * Draughts Database Schema Interface
     *
     * The schema keeps:
     * - the games in progress, one per browser session id
     * - the rooms two people play in over the web, one per room code
     * - the scoreboard, one row per player per day
     *
     * All database operations should be performed within transactions.
     */
    interface DraughtsSchema
            extends oodb.RootSchema {
        /**
         * Games, indexed by browser session ID. Each browser tab/window gets its own game.
         */
        @RO oodb.DBMap<String, GameRecord> games;

        /**
         * Rooms, indexed by room code: games played between two browsers.
         */
        @RO oodb.DBMap<String, RoomRecord> rooms;

        /**
         * Scoreboard rows, indexed by "{date}|{nickname}" (see ScoreEntry).
         */
        @RO oodb.DBMap<String, ScoreEntry> scores;
    }
}
