import db.models.CastlingRights;
import db.models.Color;

/**
 * Move Context
 * Encapsulates all contextual information needed for move validation.
 * Reduces parameter passing and makes code more maintainable.
 */
const MoveContext(
    CastlingRights? castlingRights = Null,
    String? enPassantTarget = Null,
    Color playerColor = Color.White,
    Char piece = '.'
) {
    /**
     * Check if castling is allowed for a specific side.
     */
    Boolean canCastle(Color color, Boolean kingside) {
        CastlingRights? rights = castlingRights;
        if (rights == Null) {
            return False;
        }
        if (color == Color.White) {
            return kingside ? rights.whiteKingside : rights.whiteQueenside;
        } else {
            return kingside ? rights.blackKingside : rights.blackQueenside;
        }
    }
}
