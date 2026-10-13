/**
 * Board Operations
 * Consolidates common board manipulation patterns to reduce code duplication.
 * Provides high-level operations on board state.
 */
service BoardOperations {
    /**
     * Find a specific piece on the board.
     * @param board The board to search
     * @param piece The piece character to find
     * @return The square index, or -1 if not found
     */
    static Int findPiece(Char[] board, Char piece) {
        for (Int i = 0; i < 64; i++) {
            if (board[i] == piece) {
                return i;
            }
        }
        return -1;
    }

    /**
     * Apply a move to the board (mutates the board).
     * @param board The board to modify
     * @param from Source square
     * @param to Destination square
     */
    static void applyMove(Char[] board, Int from, Int to) {
        board[to] = board[from];
        board[from] = '.';
    }

    /**
     * Create a copy of the board with a move applied.
     * @param board The original board
     * @param from Source square
     * @param to Destination square
     * @return New board array with move applied
     */
    static Char[] boardWithMove(Char[] board, Int from, Int to) {
        Char[] newBoard = new Char[64](i -> board[i]);
        applyMove(newBoard, from, to);
        return newBoard;
    }

    /**
     * Check if a move is a capture.
     */
    static Boolean isCapture(Char[] board, Int from, Int to) {
        return board[to] != '.' && board[from] != '.';
    }
}
