import db.Color;

/**
 * Board Utilities Service
 * This module provides basic board operations:
 * - Coordinate system and algebraic notation
 * - Board cloning and manipulation
 * - Square validation and color detection
 */
service BoardUtils {
    // ----- Constants -------------------------------------------------

    static Int BOARD_SIZE = 8;
    static Int FILE_STEP = 1;
    static Int RANK_STEP = 8;
    static Char FILE_MIN = 'a';
    static Char FILE_MAX = 'h';
    static Char RANK_MIN = '1';
    static Char RANK_MAX = '8';
    static Int INVALID_SQUARE = -1;

    // ----- Algebraic Notation -------------------------------------------------

    /**
     * Parse algebraic notation (e.g., "e4") to board index.
     */
    static Int parseSquare(String square) {
        if (square.size != 2) {
            return INVALID_SQUARE;
        }
        Char file = square[0];
        Char rank = square[1];
        if (file < FILE_MIN || file > FILE_MAX || rank < RANK_MIN || rank > RANK_MAX) {
            return INVALID_SQUARE;
        }
        Int fileIdx = (file - FILE_MIN).toInt();
        Int rankIdx = (RANK_MAX - rank).toInt();
        return rankIdx * RANK_STEP + fileIdx;
    }

    /**
     * Convert board index to algebraic notation.
     */
    static String toAlgebraic(Int index) {
        Int fileIdx = index % BOARD_SIZE;
        Int rankIdx = index / BOARD_SIZE;
        Char file = (FILE_MIN.toInt() + fileIdx).toChar();
        Char rank = (RANK_MAX.toInt() - rankIdx).toChar();
        return $"{file}{rank}";
    }

    // ----- Board Operations -------------------------------------------------

    /**
     * Clone the board to a mutable array.
     */
    static Char[] cloneBoard(String board) {
        Char[] mutable = new Char[64](i -> board[i]);
        return mutable;
    }

    /**
     * Convert board string to array of 8 row strings.
     */
    static String[] boardRows(String board) {
        String[] rows = new Array<String>(8, i -> board[i * 8 ..< (i + 1) * 8]);
        return rows;
    }

    /**
     * Get the color of a piece character.
     * Lowercase = Black, Uppercase = White
     */
    static Color colorOf(Char piece) {
        return piece >= 'a' && piece <= 'z' ? Color.Black : Color.White;
    }

    /**
     * Check if a square index is valid.
     */
    static Boolean isValidSquare(Int index) {
        return index >= 0 && index < 64;
    }

    /**
     * Get file (column) index from square index.
     */
    static Int getFile(Int index) {
        return index % BOARD_SIZE;
    }

    /**
     * Get rank (row) index from square index.
     */
    static Int getRank(Int index) {
        return index / BOARD_SIZE;
    }

    /**
     * Calculate distance between two squares (max of file/rank distance).
     */
    static Int getDistance(Int from, Int to) {
        Int fromFile = getFile(from);
        Int fromRank = getRank(from);
        Int toFile = getFile(to);
        Int toRank = getRank(to);
        Int fileDist = (fromFile - toFile).abs();
        Int rankDist = (fromRank - toRank).abs();
        return fileDist.maxOf(rankDist);
    }
}

