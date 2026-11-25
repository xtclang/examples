/**
 * Game Status Enumeration
 *
 * - Ongoing:   the game is in progress
 * - BlackWins: White has no legal move left (no pieces, or all blocked)
 * - WhiteWins: Black has no legal move left
 * - Draw:      40 moves each with no capture and no man moved (a house rule that stops two
 *              kings chasing each other for ever)
 */
enum GameStatus { Ongoing, BlackWins, WhiteWins, Draw }
