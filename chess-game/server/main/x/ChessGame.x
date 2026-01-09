/**
 * Chess Game Logic Module
 *
 * Main game logic module that coordinates:
 * - Move application and validation
 * - Game state management
 * - AI opponent moves
 * - Win/loss detection
 */
module ChessGame.examples.org {
    package db import chessDB.examples.org;
    package board import ChessBoard.examples.org;
    package pieces import ChessPieces.examples.org;
    package ai import ChessAI.examples.org;

    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
    import board.BoardUtils;
    import pieces.PieceValidator;
    import ai.*;

    /**
     * Move Outcome - Result of attempting a move
     */
    const MoveOutcome(Boolean ok, GameRecord record, String? message);

    /**
     * Auto Response - Result of AI move
     */
    const AutoResponse(Boolean moved, GameRecord record, String? message);

    /**
     * Main Chess Game Service
     */
    service ChessGame {
        // ----- Game Initialization -------------------------------------------------

        /**
         * Get the default starting board position.
         */
        static String defaultBoard() {
            return "rnbqkbnr" +
                   "pppppppp" +
                   "........" +
                   "........" +
                   "........" +
                   "........" +
                   "PPPPPPPP" +
                   "RNBQKBNR";
        }

        /**
         * Create a default game with starting position.
         */
        static GameRecord defaultGame() {
            return new GameRecord(defaultBoard(), Color.White);
        }

        /**
         * Reset game to initial state.
         */
        static GameRecord resetGame() {
            return defaultGame();
        }

        // ----- Move Application -------------------------------------------------

        /**
         * Apply a human player's move.
         */
        static MoveOutcome applyHumanMove(GameRecord record, String fromSquare, String toSquare, String? promotion = Null) {
            // Check if game is already finished
            if (record.status != GameStatus.Ongoing) {
                return new MoveOutcome(False, record, "Game already finished");
            }

            // Parse squares
            Int from = BoardUtils.parseSquare(fromSquare);
            Int to = BoardUtils.parseSquare(toSquare);
            if (from < 0 || to < 0) {
                return new MoveOutcome(False, record, "Invalid square format");
            }

            // Validate move
            Char[] board = BoardUtils.cloneBoard(record.board);
            Char piece = board[from];

            if (piece == '.') {
                return new MoveOutcome(False, record, "No piece on source square");
            }
            if (BoardUtils.colorOf(piece) != record.turn) {
                return new MoveOutcome(False, record, "Not your turn");
            }
            
            Char target = board[to];
            if (target != '.' && BoardUtils.colorOf(target) == record.turn) {
                return new MoveOutcome(False, record, "Cannot capture your own piece");
            }
            if (!PieceValidator.isLegal(piece, from, to, board)) {
                return new MoveOutcome(False, record, "Illegal move for that piece");
            }

            // Apply the move
            GameRecord updated = applyMove(record, board, from, to, promotion);
            return new MoveOutcome(True, updated, updated.lastMove ?: "Move applied");
        }

        /**
         * Apply a move to the board and update game state.
         */
        static GameRecord applyMove(GameRecord record, Char[] board, Int from, Int to, String? promotion) {
            Char piece = board[from];
            Char target = board[to];
            Boolean isCapture = target != '.';
            
            // Update capture scores
            Int newPlayerScore = record.playerScore;
            Int newOpponentScore = record.opponentScore;
            if (isCapture) {
                if (record.turn == Color.White) {
                    newPlayerScore++;
                } else {
                    newOpponentScore++;
                }
            }

            // Apply the move
            board[to] = piece;
            board[from] = '.';

            // Handle pawn promotion
            if (PieceValidator.isPawn(piece)) {
                Int toRank = BoardUtils.getRank(to);
                if ((piece == 'P' && toRank == 0) || (piece == 'p' && toRank == 7)) {
                    board[to] = (piece >= 'A' && piece <= 'Z') ? 'Q' : 'q'; // Promote to queen
                }
            }

            // Create move notation
            String moveStr = $"{BoardUtils.toAlgebraic(from)}{BoardUtils.toAlgebraic(to)}";

            // Switch turn
            Color nextTurn = record.turn == Color.White ? Color.Black : Color.White;

            // Check game status
            GameStatus status = checkGameStatus(new String(board), nextTurn);

            return new GameRecord(
                new String(board),
                nextTurn,
                status,
                moveStr,
                newPlayerScore,
                newOpponentScore);
        }

        // ----- AI Move -------------------------------------------------

        /**
         * Let the AI make a move (for Black).
         */
        static AutoResponse autoMove(GameRecord record) {
            if (record.status != GameStatus.Ongoing || record.turn != Color.Black) {
                return new AutoResponse(False, record, "Ready for a move");
            }

            (Int from, Int to, Int score) = ChessAI.findBestMove(record);
            
            if (from < 0 || to < 0) {
                // No legal moves available
                GameStatus status = checkGameStatus(record.board, Color.Black);
                GameRecord updated = new GameRecord(
                    record.board, record.turn, status,
                    record.lastMove, record.playerScore, record.opponentScore);
                return new AutoResponse(False, updated, "No legal moves");
            }

            // Apply the AI's move
            Char[] board = BoardUtils.cloneBoard(record.board);
            GameRecord updated = applyMove(record, board, from, to, Null);
            String moveStr = updated.lastMove ?: "AI moved";
            return new AutoResponse(True, updated, $"AI: {moveStr}");
        }

        // ----- Game Status Detection -------------------------------------------------

        /**
         * Check if the game has ended.
         */
        static GameStatus checkGameStatus(String board, Color turn) {
            // Count pieces
            Int whitePieces = 0;
            Int blackPieces = 0;
            Boolean whiteKing = False;
            Boolean blackKing = False;

            for (Char piece : board) {
                if (piece == '.') {
                    continue;
                }
                if (piece >= 'A' && piece <= 'Z') {
                    whitePieces++;
                    if (piece == 'K') {
                        whiteKing = True;
                    }
                } else {
                    blackPieces++;
                    if (piece == 'k') {
                        blackKing = True;
                    }
                }
            }

            // Checkmate: one side has no pieces left
            if (!whiteKing || whitePieces == 0) {
                return GameStatus.Checkmate;
            }
            if (!blackKing || blackPieces == 0) {
                return GameStatus.Checkmate;
            }

            // Stalemate: only kings remain
            if (whitePieces == 1 && blackPieces == 1) {
                return GameStatus.Stalemate;
            }

            return GameStatus.Ongoing;
        }

        // ----- Board Display -------------------------------------------------

        /**
         * Convert board string to array of 8 row strings for display.
         */
        static String[] boardRows(String board) {
            return BoardUtils.boardRows(board);
        }
    }
}
