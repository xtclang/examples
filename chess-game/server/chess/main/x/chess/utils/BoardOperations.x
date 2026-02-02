import db.models.Color;
import ai.EvaluationConfig;

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
     * Find all pieces of a specific type and color.
     * @param board The board to search
     * @param pieceType The piece type ('p', 'n', 'b', 'r', 'q', 'k')
     * @param color The color to match
     * @return Array of square indices
     */
    static Int[] findPieces(Char[] board, Char pieceType, Color color) {
        Char targetChar = color == Color.White ? pieceType.uppercase : pieceType.lowercase;
        Int[] positions = new Int[];
        for (Int i = 0; i < 64; i++) {
            if (board[i] == targetChar) {
                positions = positions.add(i);
            }
        }
        return positions;
    }

    /**
     * Count pieces of a specific color on the board.
     */
    static Int countPieces(Char[] board, Color color) {
        Int count = 0;
        for (Int i = 0; i < 64; i++) {
            Char piece = board[i];
            if (piece != '.' && BoardUtils.colorOf(piece) == color) {
                count++;
            }
        }
        return count;
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
     * Check if a square is empty.
     */
    static Boolean isEmpty(Char[] board, Int square) {
        return BoardUtils.isValidSquare(square) && board[square] == '.';
    }

    /**
     * Check if a square is occupied by a piece of specific color.
     */
    static Boolean isOccupiedBy(Char[] board, Int square, Color color) {
        if (!BoardUtils.isValidSquare(square)) {
            return False;
        }
        Char piece = board[square];
        return piece != '.' && BoardUtils.colorOf(piece) == color;
    }

    /**
     * Get all occupied squares for a color.
     */
    static Int[] getOccupiedSquares(Char[] board, Color color) {
        Int[] squares = new Int[];
        for (Int i = 0; i < 64; i++) {
            if (isOccupiedBy(board, i, color)) {
                squares = squares.add(i);
            }
        }
        return squares;
    }

    /**
     * Calculate material balance (positive = White ahead, negative = Black ahead).
     */
    static Int calculateMaterialBalance(Char[] board, EvaluationConfig config) {
        Int whiteValue = 0;
        Int blackValue = 0;
        
        for (Int i = 0; i < 64; i++) {
            Char piece = board[i];
            if (piece == '.') {
                continue;
            }
            Int value = config.getPieceValue(piece);
            if ('A' <= piece <= 'Z') {
                whiteValue += value;
            } else {
                blackValue += value;
            }
        }
        
        return whiteValue - blackValue;
    }

    /**
     * Check if a move is a capture.
     */
    static Boolean isCapture(Char[] board, Int from, Int to) {
        return board[to] != '.' && board[from] != '.';
    }

    /**
     * Check if two squares are adjacent (touching, including diagonals).
     */
    static Boolean areAdjacent(Int square1, Int square2) {
        return BoardUtils.getDistance(square1, square2) == 1;
    }

    /**
     * Get all empty squares on the board.
     */
    static Int[] getEmptySquares(Char[] board) {
        Int[] squares = new Int[];
        for (Int i = 0; i < 64; i++) {
            if (board[i] == '.') {
                squares = squares.add(i);
            }
        }
        return squares;
    }

    /**
     * Convert board array to string representation.
     */
    static String boardToString(Char[] board) {
        return new String(board);
    }

    /**
     * Validate board integrity (has exactly one king of each color).
     */
    static Boolean isValidBoard(Char[] board) {
        Int whiteKings = 0;
        Int blackKings = 0;
        
        for (Int i = 0; i < 64; i++) {
            Char piece = board[i];
            if (piece == 'K') {
                whiteKings++;
            } else if (piece == 'k') {
                blackKings++;
            }
        }
        
        return whiteKings == 1 && blackKings == 1;
    }
}
