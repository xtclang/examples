/**
 * Game Status Enumeration
 * 
 * Tracks the lifecycle and outcome of a chess game.
 * 
 * - Ongoing:    Game is still in progress, moves can be made
 * - Checkmate:  Game has ended because one player has no pieces left
 *               (simplified from traditional checkmate rules)
 * - Stalemate:  Game has ended in a draw because only kings remain
 *               on the board
 * 
 * Note: This implementation uses simplified win/loss conditions rather
 * than traditional chess checkmate and stalemate rules.
 */
enum GameStatus { Ongoing, Checkmate, Stalemate }
