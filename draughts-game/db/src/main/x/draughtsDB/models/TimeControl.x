/**
 * Time Control - the clocks of a timed room.
 *
 * Each player has a bank of time that runs down only while it is their turn, and a small
 * increment is added to it after each of their moves. Neither clock runs before the first move.
 *
 * The figures are what each player had at `lastMoveTime`, when the last move was made; the time
 * since then is taken off the player to move whenever the clocks are read (see GameClock).
 *
 * @param initialMs    Time each player started with, in milliseconds (kept for a rematch)
 * @param incrementMs  Time added to a player's clock after each of their moves
 * @param blackMs      Black's time at `lastMoveTime`
 * @param whiteMs      White's time at `lastMoveTime`
 * @param lastMoveTime When the last move was made (or when the clocks were set, before any move)
 */
const TimeControl(Int initialMs,
                  Int incrementMs,
                  Int blackMs,
                  Int whiteMs,
                  Time lastMoveTime) {}
