/**
 * Game Status Enumeration
 * 
 * Tracks the lifecycle and outcome of a chess game using standard chess rules.
 * 
 * - Ongoing:              Game is still in progress, moves can be made
 * - Checkmate:            Game ended by checkmate (no legal moves while in check)
 * - Stalemate:            Draw - no legal moves but not in check
 * - FiftyMoveRule:        Draw - 50 moves without a pawn move or capture
 * - InsufficientMaterial: Draw - neither side can force checkmate
 * - ThreefoldRepetition:  Draw - same position occurred three times
 * - Timeout:              Game ended because a player ran out of time
 */
enum GameStatus { Ongoing, Checkmate, Stalemate, FiftyMoveRule, InsufficientMaterial, ThreefoldRepetition, Timeout }
