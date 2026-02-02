/**
 * Direction Utilities
 * Provides abstractions for board direction calculations and path operations.
 * Reduces duplication in piece movement validation.
 */
service DirectionUtils {
    // Direction constants
    static Int NORTH = -8;
    static Int SOUTH = 8;
    static Int EAST = 1;
    static Int WEST = -1;
    static Int NORTHEAST = -7;
    static Int NORTHWEST = -9;
    static Int SOUTHEAST = 9;
    static Int SOUTHWEST = 7;

    /**
     * Calculate step increment for moving between two squares.
     * Returns 0 if not a straight or diagonal line.
     */
    static Int calculateStep(Int from, Int to) {
        Int diff = to - from;
        Int fileFrom = BoardUtils.getFile(from);
        Int fileTo = BoardUtils.getFile(to);
        Int rankFrom = BoardUtils.getRank(from);
        Int rankTo = BoardUtils.getRank(to);

        // Horizontal movement
        if (rankFrom == rankTo) {
            return diff > 0 ? EAST : WEST;
        }
        // Vertical movement
        if (fileFrom == fileTo) {
            return diff > 0 ? SOUTH : NORTH;
        }
        // Diagonal movement
        Int fileDiff = (fileTo - fileFrom).abs();
        Int rankDiff = (rankTo - rankFrom).abs();
        if (fileDiff == rankDiff) {
            if (diff > 0) {
                return fileTo > fileFrom ? SOUTHEAST : SOUTHWEST;
            } else {
                return fileTo > fileFrom ? NORTHEAST : NORTHWEST;
            }
        }
        return 0;
    }

    /**
     * Check if path is clear between two squares.
     * Used for sliding pieces (rook, bishop, queen).
     */
    static Boolean isPathClear(Int from, Int to, Char[] board) {
        Int step = calculateStep(from, to);
        if (step == 0) {
            return False;
        }
        Int current = from + step;
        while (current != to) {
            if (board[current] != '.') {
                return False;
            }
            current += step;
        }
        return True;
    }

    /**
     * Check if two squares are on the same file (column).
     */
    static Boolean isSameFile(Int from, Int to) {
        return BoardUtils.getFile(from) == BoardUtils.getFile(to);
    }

    /**
     * Check if two squares are on the same rank (row).
     */
    static Boolean isSameRank(Int from, Int to) {
        return BoardUtils.getRank(from) == BoardUtils.getRank(to);
    }

    /**
     * Check if two squares are on the same diagonal.
     */
    static Boolean isSameDiagonal(Int from, Int to) {
        Int fileDiff = (BoardUtils.getFile(to) - BoardUtils.getFile(from)).abs();
        Int rankDiff = (BoardUtils.getRank(to) - BoardUtils.getRank(from)).abs();
        return fileDiff == rankDiff && fileDiff > 0;
    }

    /**
     * Check if move is along a straight line (horizontal or vertical).
     */
    static Boolean isStraightLine(Int from, Int to) {
        return (isSameFile(from, to) || isSameRank(from, to)) && from != to;
    }

    /**
     * Get all squares along a ray in a specific direction.
     * Useful for sliding piece attack detection.
     */
    static Int[] getRaySquares(Int from, Int direction, Int maxDistance = 8) {
        Int[] squares = new Int[];
        Int current = from + direction;
        Int distance = 0;

        Loop:
        while (BoardUtils.isValidSquare(current) && distance < maxDistance) {
        // Check for wrapping (file overflow)
                Int fromFile = BoardUtils.getFile(from);
                Int currentFile = BoardUtils.getFile(current);

                switch (direction) {
                case EAST, NORTHEAST, SOUTHEAST:
                    if (currentFile < fromFile) {
                        break Loop;
                    }
                    break;

                case WEST, NORTHWEST, SOUTHWEST:
                    if (currentFile > fromFile) {
                        break Loop;
                    }
                    break;
                }

                squares = squares.add(current);
                current += direction;
                distance++;
        }
        return squares;
    }
}
