/**
 * Chess AI Module
 *
 * Simple heuristic-based AI for the opponent (Black player).
 * Evaluates moves based on:
 * - Piece captures (material gain)
 * - Position (center control)
 * - Pawn promotion
 */
module ChessAI.examples.org {
    package db import chessDB.examples.org;
    package board import ChessBoard.examples.org;
    package pieces import ChessPieces.examples.org;
    
    import db.GameRecord;
    import db.Color;
    import board.BoardUtils;
    import pieces.PieceValidator;

    /**
     * AI Move Selection
     */
    service ChessAI {
        // ----- Scoring Constants -------------------------------------------------
        
        static Int CENTER_FILE = 3;
        static Int CENTER_RANK = 3;
        static Int CENTER_BONUS = 5;
        static Int PROMOTION_BONUS = 8;
        static Int MIN_SCORE = -10000;

        // Piece values
        static Int PAWN_VALUE = 1;
        static Int KNIGHT_VALUE = 3;
        static Int BISHOP_VALUE = 3;
        static Int ROOK_VALUE = 5;
        static Int QUEEN_VALUE = 9;

        // ----- Piece Value Calculation -------------------------------------------------

        /**
         * Get the value of a piece for scoring.
         */
        static Int getPieceValue(Char piece) {
            Char lower = piece.lowercase;
            switch (lower) {
                case 'p': return PAWN_VALUE;
                case 'n': return KNIGHT_VALUE;
                case 'b': return BISHOP_VALUE;
                case 'r': return ROOK_VALUE;
                case 'q': return QUEEN_VALUE;
                case 'k': return 0; // King capture ends game
                default: return 0;
            }
        }

        /**
         * Calculate position score (bonus for center control).
         */
        static Int getPositionScore(Int square) {
            Int file = BoardUtils.getFile(square);
            Int rank = BoardUtils.getRank(square);
            Int fileDist = (file - CENTER_FILE).abs();
            Int rankDist = (rank - CENTER_RANK).abs();
            Int maxDist = fileDist.maxOf(rankDist);
            return maxDist == 0 ? CENTER_BONUS : CENTER_BONUS / (maxDist + 1);
        }

        /**
         * Check if a pawn move results in promotion.
         */
        static Boolean isPromotion(Char piece, Int to) {
            if (piece == 'p') {
                return BoardUtils.getRank(to) == 7; // Black pawn to rank 1
            }
            return False;
        }

        // ----- Move Scoring -------------------------------------------------

        /**
         * Score a potential move for the AI.
         */
        static Int scoreMove(Char piece, Int from, Int to, Char[] board, GameRecord record) {
            Int score = 0;
            Char target = board[to];

            // Capture value
            if (target != '.') {
                score += getPieceValue(target) * 10;
            }

            // Position bonus (move toward center)
            score += getPositionScore(to);

            // Promotion bonus
            if (isPromotion(piece, to)) {
                score += PROMOTION_BONUS;
            }

            return score;
        }

        // ----- Best Move Selection -------------------------------------------------

        /**
         * Find the best move for Black (AI opponent).
         * Returns (from, to, score) tuple.
         */
        static (Int, Int, Int) findBestMove(GameRecord record) {
            Char[] board = BoardUtils.cloneBoard(record.board);
            Int bestScore = MIN_SCORE;
            Int bestFrom = -1;
            Int bestTo = -1;

            // Try all possible moves for Black pieces
            for (Int from : 0 ..< 64) {
                Char piece = board[from];
                if (piece == '.' || BoardUtils.colorOf(piece) != Color.Black) {
                    continue;
                }

                // Try all target squares
                for (Int to : 0 ..< 64) {
                    if (from == to) {
                        continue;
                    }
                    Char target = board[to];
                    // Can't capture own piece
                    if (target != '.' && BoardUtils.colorOf(target) == Color.Black) {
                        continue;
                    }
                    // Check if move is legal
                    if (!PieceValidator.isLegal(piece, from, to, board)) {
                        continue;
                    }

                    // Score this move
                    Int score = scoreMove(piece, from, to, board, record);
                    if (score > bestScore) {
                        bestScore = score;
                        bestFrom = from;
                        bestTo = to;
                    }
                }
            }

            return (bestFrom, bestTo, bestScore);
        }
    }
}
