import db.models.CastlingRights;
import db.models.Color;

/**
 * Move Strategy Interface
 * Defines a common interface for different piece movement strategies.
 * This enables the Strategy pattern for piece validation, reducing code duplication.
 */
interface MoveStrategy {
    /**
     * Validate if a move is legal for this piece type.
     * 
     * @param from Source square index (0-63)
     * @param to Destination square index (0-63)
     * @param board Current board state
     * @param context Additional context (castling rights, en passant, etc.)
     * @return True if the move is valid for this piece type
     */
    Boolean validateMove(Int from, Int to, Char[] board, MoveContext context);
}
