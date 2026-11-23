/**
 * Game Record - Immutable Game State Snapshot
 *
 * Board Representation:
 * The board is a 64-character string in row-major order, row 0 (the top of the screen) first:
 * - Characters 0-7:   Row 0 (a8-h8) - White's back row, where Black's men are crowned
 * - ...
 * - Characters 56-63: Row 7 (a1-h1) - Black's back row, where White's men are crowned
 *
 * Only dark squares are used: a square is dark when (row + column) is odd.
 *
 * Piece notation:
 * - 'b' Black man, 'B' Black king
 * - 'w' White man, 'W' White king
 * - '.' empty square
 *
 * @param board       64-character string representing the board state
 * @param turn        Which color's turn it is to move
 * @param status      Current game status
 * @param blackName   Nickname of the player with the Black pieces (moves first)
 * @param whiteName   Nickname of the player with the White pieces
 * @param quietPlies  Half-moves since the last capture or man move (for the draw rule)
 * @param lastMove    The last move's path (e.g. "c3-e5"), or Null if no moves yet
 * @param history     Every move made, in order
 */
const GameRecord(String board,
                 Color turn = Black,
                 GameStatus status = Ongoing,
                 String blackName = "Black",
                 String whiteName = "White",
                 Int quietPlies = 0,
                 String? lastMove = Null,
                 MoveEntry[] history = []) {}
