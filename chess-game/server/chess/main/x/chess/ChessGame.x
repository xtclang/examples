import ChessAI.*;
import db.CastlingRights;
import db.MoveHistoryEntry;


/**
 * Main Chess Game Service
 * Main game logic module that coordinates:
 * - Move application and validation
  * - Game state management
  * - AI opponent moves
  * - Win/loss detection
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
        if (record.status != Ongoing) {
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
        if (!PieceValidator.isLegal(piece, from, to, board, record.castlingRights, record.enPassantTarget)) {
            return new MoveOutcome(False, record, "Illegal move for that piece");
        }

        // Check if move leaves king in check
        if (!CheckDetection.isMoveLegalWithCheck(board, from, to, record.turn)) {
            return new MoveOutcome(False, record, "Move leaves king in check");
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
        Boolean isCastling = False;
        Boolean isEnPassant = False;
        String? castleType = Null;

        // Update capture scores
        Int newPlayerScore = record.playerScore;
        Int newOpponentScore = record.opponentScore;
        Int newHalfMoveClock = record.halfMoveClock + 1;
        
        // Reset half-move clock on pawn move or capture
        if (PieceValidator.isPawn(piece) || isCapture) {
            newHalfMoveClock = 0;
        }

        // Check for castling
        if (PieceValidator.isKing(piece)) {
            Int fileDiff = (BoardUtils.getFile(to) - BoardUtils.getFile(from)).abs();
            if (fileDiff == 2) {
                isCastling = True;
                Boolean isKingside = BoardUtils.getFile(to) > BoardUtils.getFile(from);
                castleType = isKingside ? "O-O" : "O-O-O";
                
                // Move the rook
                Int rookFrom = isKingside ? from + 3 : from - 4;
                Int rookTo = isKingside ? from + 1 : from - 1;
                board[rookTo] = board[rookFrom];
                board[rookFrom] = '.';
            }
        }

        // Check for en passant
        if (PieceValidator.isPawn(piece) && record.enPassantTarget != Null) {
            String toSquare = BoardUtils.toAlgebraic(to);
            if (toSquare == record.enPassantTarget && !isCapture) {
                isEnPassant = True;
                // Remove the captured pawn
                Int capturedPawnSquare = record.turn == White ? to + 8 : to - 8;
                board[capturedPawnSquare] = '.';
                if (record.turn == Color.White) {
                    newPlayerScore++;
                } else {
                    newOpponentScore++;
                }
            }
        }

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

        // Determine new en passant target
        String? newEnPassantTarget = Null;
        if (PieceValidator.isPawn(piece)) {
            Int rankDiff = (BoardUtils.getRank(to) - BoardUtils.getRank(from)).abs();
            if (rankDiff == 2) {
                // Pawn moved two squares, set en passant target
                Int epSquare = record.turn == White ? from - 8 : from + 8;
                newEnPassantTarget = BoardUtils.toAlgebraic(epSquare);
            }
        }

        // Handle pawn promotion
        Char? promotedTo = Null;
        if (PieceValidator.isPawn(piece)) {
            Int toRank = BoardUtils.getRank(to);
            if ((piece == 'P' && toRank == 0) || (piece == 'p' && toRank == 7)) {
                Char promoPiece = (piece >= 'A' && piece <= 'Z') ? 'Q' : 'q';
                board[to] = promoPiece;
                promotedTo = promoPiece;
            }
        }

        // Update castling rights
        CastlingRights newCastlingRights = updateCastlingRights(record.castlingRights, piece, from, to);

        // Create move notation
        String moveStr = $"{BoardUtils.toAlgebraic(from)}{BoardUtils.toAlgebraic(to)}";

        // Switch turn
        Color nextTurn = record.turn == Color.White ? Color.Black : Color.White;

        // Check if move gives check
        String boardStr = new String(board);
        Boolean givesCheck = CheckDetection.isInCheck(boardStr, nextTurn);

        // Check game status (checkmate/stalemate)
        (Boolean isCheckmate, Boolean isStalemate) = CheckDetection.checkGameEnd(
            boardStr, nextTurn, newCastlingRights, newEnPassantTarget);

        GameStatus status = isCheckmate ? GameStatus.Checkmate :
                           isStalemate ? GameStatus.Stalemate :
                           GameStatus.Ongoing;

        // Create move history entry
        Int moveNumber = record.moveHistory.size + 1;
        String notation = createMoveNotation(piece, from, to, isCapture, promotedTo, givesCheck, isCheckmate, castleType);
        MoveHistoryEntry historyEntry = new MoveHistoryEntry(
            moveNumber, record.turn, BoardUtils.toAlgebraic(from), BoardUtils.toAlgebraic(to),
            piece, isCapture ? target : Null, promotedTo, givesCheck, isCheckmate,
            castleType, isEnPassant, notation, boardStr);

        MoveHistoryEntry[] newHistory = record.moveHistory.addAll([historyEntry]);

        return new GameRecord(
            boardStr,
            nextTurn,
            status,
            moveStr,
            newPlayerScore,
            newOpponentScore,
            newCastlingRights,
            newEnPassantTarget,
            newHistory,
            record.timeControl,
            newHalfMoveClock);
    }

    /**
     * Update castling rights based on a move.
     */
    static CastlingRights updateCastlingRights(CastlingRights rights, Char piece, Int from, Int to) {
        Boolean whiteKingside = rights.whiteKingside;
        Boolean whiteQueenside = rights.whiteQueenside;
        Boolean blackKingside = rights.blackKingside;
        Boolean blackQueenside = rights.blackQueenside;

        // If king moves, lose all castling rights for that color
        if (piece == 'K') {
            whiteKingside = False;
            whiteQueenside = False;
        } else if (piece == 'k') {
            blackKingside = False;
            blackQueenside = False;
        }

        // If rook moves from starting position, lose that side's castling
        if (piece == 'R') {
            if (from == 63) { whiteKingside = False; }  // h1
            if (from == 56) { whiteQueenside = False; } // a1
        } else if (piece == 'r') {
            if (from == 7) { blackKingside = False; }   // h8
            if (from == 0) { blackQueenside = False; }  // a8
        }

        // If rook is captured, lose that side's castling
        if (to == 63) { whiteKingside = False; }  // h1
        if (to == 56) { whiteQueenside = False; } // a1
        if (to == 7) { blackKingside = False; }   // h8
        if (to == 0) { blackQueenside = False; }  // a8

        return new CastlingRights(whiteKingside, whiteQueenside, blackKingside, blackQueenside);
    }

    /**
     * Create standard algebraic notation for a move.
     */
    static String createMoveNotation(Char piece, Int from, Int to, Boolean isCapture,
                                     Char? promotion, Boolean isCheck, Boolean isCheckmate,
                                     String? castling) {
        if (castling != Null) {
            String suffix = isCheckmate ? "#" : isCheck ? "+" : "";
            return $"{castling}{suffix}";
        }

        String pieceSymbol = PieceValidator.isPawn(piece) ? "" : piece.uppercase.toString();
        String captureSymbol = isCapture ? "x" : "";
        String toSquare = BoardUtils.toAlgebraic(to);
        String promoSymbol = promotion != Null ? $"={promotion.uppercase}" : "";
        String checkSymbol = isCheckmate ? "#" : isCheck ? "+" : "";

        return $"{pieceSymbol}{captureSymbol}{toSquare}{promoSymbol}{checkSymbol}";
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
     * Check if the game has ended (legacy method for backward compatibility).
     */
    static GameStatus checkGameStatus(String board, Color turn) {
        // Use simplified legacy rules for backward compatibility
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

        // Checkmate: one side has no king
        if (!whiteKing || !blackKing) {
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

    /**
     * Move Outcome - Result of attempting a move
     */
    static const MoveOutcome(Boolean ok, GameRecord record, String? message);

    /**
     * Auto Response - Result of AI move
     */
    static const AutoResponse(Boolean moved, GameRecord record, String? message);

}
