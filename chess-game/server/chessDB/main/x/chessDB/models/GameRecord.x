/**
 * Game Record - Immutable Game State Snapshot
 * 
 * Represents a complete snapshot of a chess game at a specific point in time.
 * All game state is persisted in the database as GameRecord instances.
 * 
 * Board Representation:
 * The board is stored as a 64-character string in row-major order from a8 to h1:
 * - Characters 0-7:   Rank 8 (a8-h8) - Black's back rank
 * - Characters 8-15:  Rank 7 (a7-h7) - Black's pawn rank
 * - Characters 16-23: Rank 6 (a6-h6)
 * - Characters 24-31: Rank 5 (a5-h5)
 * - Characters 32-39: Rank 4 (a4-h4)
 * - Characters 40-47: Rank 3 (a3-h3)
 * - Characters 48-55: Rank 2 (a2-h2) - White's pawn rank
 * - Characters 56-63: Rank 1 (a1-h1) - White's back rank
 * 
 * Piece notation:
 * - Uppercase letters (R,N,B,Q,K,P) = White pieces
 * - Lowercase letters (r,n,b,q,k,p) = Black pieces
 * - Period (.) = Empty square
 * 
 * @param board          64-character string representing the board state
 * @param turn           Which color's turn it is to move
 * @param status         Current game status (Ongoing, Checkmate, or Stalemate)
 * @param lastMove       Last move made in algebraic notation (e.g., "e2e4"), or null if no moves yet
 * @param playerScore    Number of Black pieces captured by White (player)
 * @param opponentScore  Number of White pieces captured by Black (opponent)
 * @param castlingRights Tracks which castling moves are still legal
 * @param enPassantTarget Square where en passant capture is possible (e.g., "e3"), or null
 * @param moveHistory    Complete history of all moves made in the game
 * @param timeControl    Time remaining and settings for each player
 * @param halfMoveClock  Number of half-moves since last capture or pawn move (for 50-move rule)
 */
const GameRecord(String board,
                 Color  turn,
                 GameStatus status = Ongoing,
                 String? lastMove = Null,
                 Int playerScore = 0,
                 Int opponentScore = 0,
                 CastlingRights castlingRights = new CastlingRights(),
                 String? enPassantTarget = Null,
                 MoveHistoryEntry[] moveHistory = [],
                 TimeControl? timeControl = Null,
                 Int halfMoveClock = 0) {}
