/**
 * Piece Factory
 * Provides factory methods for creating chess pieces.
 * Reduces duplication and centralizes piece creation logic.
 */
service PieceFactory {
    /**
     * Create a piece by type and color.
     * @param pieceType The piece type character ('p', 'n', 'b', 'r', 'q', 'k')
     * @param color The color of the piece
     * @return The created piece conditionally (True if valid type)
     */
    static conditional Piece createPiece(Char pieceType, Color color) {
        Char lower = pieceType.lowercase;
        return switch (lower) {
            case 'p': (True, new Pawn(color));
            case 'n': (True, new Knight(color));
            case 'b': (True, new Bishop(color));
            case 'r': (True, new Rook(color));
            case 'q': (True, new Queen(color));
            case 'k': (True, new King(color));
            default: False;
        };
    }

    /**
     * Get piece info from a board character.
     * @param pieceChar The character from the board
     * @return Tuple of (pieceType, color, value) conditionally
     */
    static conditional (Char, Color, Int) getPieceInfo(Char pieceChar) {
        if (pieceChar == '.') {
            return False;
        }
        
        Char lower = pieceChar.lowercase;
        Color color = pieceChar >= 'a' && pieceChar <= 'z' ? Black : White;
        
        // Get centipawn value
        Int value = switch (lower) {
            case 'p': 100;
            case 'n': 320;
            case 'b': 330;
            case 'r': 500;
            case 'q': 900;
            case 'k': 20000;
            default: 0;
        };
        
        return (True, lower, color, value);
    }

    /**
     * Check if a character represents a specific piece type.
     */
    static Boolean isPieceType(Char pieceChar, Char pieceType) {
        return pieceChar.lowercase == pieceType.lowercase;
    }

    /**
     * Get all standard pieces for starting a game.
     * @param color The color of pieces to create
     * @return Array of all 16 pieces for one side
     */
    static Piece[] createStandardSet(Color color) {
        return [
            new Rook(color),
            new Knight(color),
            new Bishop(color),
            new Queen(color),
            new King(color),
            new Bishop(color),
            new Knight(color),
            new Rook(color),
            new Pawn(color),
            new Pawn(color),
            new Pawn(color),
            new Pawn(color),
            new Pawn(color),
            new Pawn(color),
            new Pawn(color),
            new Pawn(color)
        ];
    }
}
