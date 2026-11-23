/**
 * Move Entry - one move in the game's history.
 *
 * @param moveNumber  Sequential ply number, starting at 1
 * @param color       Who made the move
 * @param path        The squares the piece visited, joined by "-" (e.g. "c3-d4" or "c3-e5-g7")
 * @param captures    How many pieces the move captured
 * @param crowned     True if the move crowned a man
 * @param notation    Display notation: "c3-d4" for a step, "c3xe5xg7" for captures
 * @param boardAfter  The 64-character board after the move, for stepping back through the game
 */
const MoveEntry(Int moveNumber,
                Color color,
                String path,
                Int captures,
                Boolean crowned,
                String notation,
                String boardAfter) {}
