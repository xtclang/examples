/**
 * Castling Rights - Track which castling moves are still available
 * 
 * Each player can castle kingside (O-O) and queenside (O-O-O) if:
 * - Neither the king nor the rook has moved
 * - There are no pieces between king and rook
 * - The king is not in check, doesn't pass through check, and doesn't end in check
 */
const CastlingRights(Boolean whiteKingside = True,
                     Boolean whiteQueenside = True,
                     Boolean blackKingside = True,
                     Boolean blackQueenside = True) {}
