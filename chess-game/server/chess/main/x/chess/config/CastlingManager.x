import db.models.CastlingRights;

/**
 * Castling Rights Manager
 * Encapsulates logic for updating castling rights based on moves.
 * Reduces complexity in game state management.
 */
service CastlingManager {
    /**
     * Update castling rights after a move.
     * Castling rights are lost when:
     * - The king moves
     * - A rook moves from its starting position
     * - A rook is captured from its starting position
     * 
     * @param rights Current castling rights
     * @param piece The piece that moved
     * @param from Source square
     * @param to Destination square
     * @return Updated castling rights
     */
    static CastlingRights updateRights(CastlingRights rights, Char piece, Int from, Int to) {
        Boolean whiteKingside = rights.whiteKingside;
        Boolean whiteQueenside = rights.whiteQueenside;
        Boolean blackKingside = rights.blackKingside;
        Boolean blackQueenside = rights.blackQueenside;

        // White king moves - lose all white castling rights
         switch(piece){
            case 'K':
                whiteKingside = False;
                whiteQueenside = False;
                break;
            case 'k':
                blackKingside = False;
                blackQueenside = False;
                break;
            case 'R':
                if (from == 63) { // h1
                    whiteKingside = False;
                } else if (from == 56) { // a1
                    whiteQueenside = False;
                }
                break;
            case 'r':
                if (from == 7) { // h8
                    blackKingside = False;
                } else if (from == 0) { // a8
                    blackQueenside = False;
                }
                break;
            default:
                break;
        }

        // Check if a rook was captured on its starting square
        // This also revokes castling rights
        if (to == 63) { // h1
            whiteKingside = False;
        } else if (to == 56) { // a1
            whiteQueenside = False;
        } else if (to == 7) { // h8
            blackKingside = False;
        } else if (to == 0) { // a8
            blackQueenside = False;
        }

        return new CastlingRights(whiteKingside, whiteQueenside, blackKingside, blackQueenside);
    }

    /**
     * Check if castling is available for a specific side.
     */
    static Boolean canCastle(CastlingRights rights, Color color, Boolean kingside) {
            return color == White
                    ? (kingside ? rights.whiteKingside : rights.whiteQueenside)
                    : (kingside ? rights.blackKingside : rights.blackQueenside);
    }

    /**
     * Create default castling rights (all castling available).
     */
    static CastlingRights defaultRights() {
        return new CastlingRights(True, True, True, True);
    }

    /**
     * Create castling rights with no castling available.
     */
    static CastlingRights noRights() {
        return new CastlingRights(False, False, False, False);
    }

    /**
     * Get a string representation of castling rights (FEN notation).
     */
    static String toFEN(CastlingRights rights) {
        String fen = "";
        if (rights.whiteKingside) {
            fen += "K";
        }
        if (rights.whiteQueenside) {
            fen += "Q";
        }
        if (rights.blackKingside) {
            fen += "k";
        }
        if (rights.blackQueenside) {
            fen += "q";
        }
        return fen.empty ? "-" : fen;
    }
}
