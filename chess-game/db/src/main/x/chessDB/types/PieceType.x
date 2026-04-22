/**
 * Piece Type Enumeration
 * Defines all chess piece types with their properties.
 * Centralizes piece metadata to reduce duplication.
 */
enum PieceType(Char symbol, Int value, String displayName) {
    Pawn('p', 100, "Pawn"),
    Knight('n', 320, "Knight"),
    Bishop('b', 330, "Bishop"),
    Rook('r', 500, "Rook"),
    Queen('q', 900, "Queen"),
    King('k', 20000, "King");

    /**
     * Get piece type from character.
     */
    static conditional PieceType fromChar(Char ch) {
        Char lower = ch.lowercase;
        for (PieceType type : PieceType.values) {
            if (type.symbol == lower) {
                return True, type;
            }
        }
        return False;
    }

    /**
     * Check if this is a sliding piece (moves along ranks, files, or diagonals).
     */
    Boolean isSliding() {
        return this == Bishop || this == Rook || this == Queen;
    }

    /**
     * Check if this is a major piece (Rook or Queen).
     */
    Boolean isMajorPiece() {
        return this == Rook || this == Queen;
    }

    /**
     * Check if this is a minor piece (Bishop or Knight).
     */
    Boolean isMinorPiece() {
        return this == Bishop || this == Knight;
    }

    /**
     * Get the character representation for a specific color.
     */
    Char getChar(Color color) {
        return color == Color.White ? symbol.uppercase : symbol.lowercase;
    }
}
