/**
 * Move History Entry - Represents a single move in the game
 * 
 * @param moveNumber     Sequential move number (increments each full turn)
 * @param color          Which player made the move
 * @param fromSquare     Source square in algebraic notation (e.g., "e2")
 * @param toSquare       Destination square in algebraic notation (e.g., "e4")
 * @param piece          The piece that moved (e.g., 'P', 'N', 'B', 'R', 'Q', 'K')
 * @param capturedPiece  The piece captured, if any
 * @param promotion      Piece promoted to, if applicable (e.g., 'Q')
 * @param isCheck        Whether the move puts opponent in check
 * @param isCheckmate    Whether the move results in checkmate
 * @param isCastle       Whether the move is castling (kingside or queenside)
 * @param isEnPassant    Whether the move is an en passant capture
 * @param notation       Standard algebraic notation (e.g., "Nf3", "e4", "O-O")
 * @param boardAfter     Board state after this move
 */
const MoveHistoryEntry(Int moveNumber,
                       Color color,
                       String fromSquare,
                       String toSquare,
                       Char piece,
                       Char? capturedPiece = Null,
                       Char? promotion = Null,
                       Boolean isCheck = False,
                       Boolean isCheckmate = False,
                       String? isCastle = Null,
                       Boolean isEnPassant = False,
                       String notation = "",
                       String boardAfter = "") {}
