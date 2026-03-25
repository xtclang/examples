import db.models.CastlingRights;
import db.models.MoveHistoryEntry;


/**
 * Main Chess Game Service
 * Main game logic module that coordinates:
 * - Move application and validation
 * - Game state management
 * - AI opponent moves (via external Stockfish API)
 * - Win/loss detection
 */
@Abstract
class ChessGame {
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
        return new GameRecord(defaultBoard(), White, GameStatus.Ongoing, Null, 0, 0,
                             new CastlingRights(), Null, [], Null, 0);
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

        // Validate move using abstraction
        Char[] board = BoardUtils.cloneBoard(record.board);
        MoveValidator.ValidationResult validation = MoveValidator.validateMove(
            board, from, to, record.turn, record.castlingRights, record.enPassantTarget
        );
        
        if (!validation.isValid) {
            return new MoveOutcome(False, record, validation.errorMessage ?: "Invalid move");
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
                if (record.turn == White) {
                    newPlayerScore++;
                } else {
                    newOpponentScore++;
                }
            }
        }

        if (isCapture) {
            if (record.turn == White) {
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
                Char promoPiece = ('A' <= piece <= 'Z') ? 'Q' : 'q';
                board[to] = promoPiece;
                promotedTo = promoPiece;
            }
        }

        // Update castling rights using abstraction
        CastlingRights newCastlingRights = CastlingManager.updateRights(record.castlingRights, piece, from, to);

        // Create move notation
        String moveStr = $"{BoardUtils.toAlgebraic(from)}{BoardUtils.toAlgebraic(to)}";

        // Switch turn
        Color nextTurn = record.turn == White ? Black : White;

        // Check if move gives check
        String boardStr = new String(board);
        Boolean givesCheck = CheckDetection.isInCheck(board.freeze(), nextTurn);

        // Check game status (checkmate/stalemate/draws)
        (Boolean isCheckmate, Boolean isStalemate) = CheckDetection.checkGameEnd(
            boardStr, nextTurn, newCastlingRights, newEnPassantTarget);

        GameStatus status;
        if (isCheckmate) {
            status = Checkmate;
        } else if (isStalemate) {
            status = Stalemate;
        } else if (CheckDetection.isFiftyMoveRule(newHalfMoveClock)) {
            status = FiftyMoveRule;
        } else if (CheckDetection.isInsufficientMaterial(boardStr)) {
            status = InsufficientMaterial;
        } else {
            status = Ongoing;
        }

        // Create move history entry
        Int moveNumber = record.moveHistory.size + 1;
        String notation = createMoveNotation(piece, from, to, isCapture, promotedTo, givesCheck, isCheckmate, castleType);
        MoveHistoryEntry historyEntry = new MoveHistoryEntry(
            moveNumber, record.turn, BoardUtils.toAlgebraic(from), BoardUtils.toAlgebraic(to),
            piece, isCapture ? target : Null, promotedTo, givesCheck, isCheckmate,
            castleType, isEnPassant, notation, boardStr);

        MoveHistoryEntry[] newHistory = record.moveHistory.addAll([historyEntry]);

        // Check threefold repetition (must be done after building history)
        if (status == Ongoing
                && CheckDetection.isThreefoldRepetition(
                       newHistory, boardStr, nextTurn, newCastlingRights, newEnPassantTarget)) {
            status = ThreefoldRepetition;
        }

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
     * Apply an AI move returned by the external Stockfish API.
     *
     * @param record    current game state
     * @param from      source square index
     * @param to        destination square index
     * @param promotion optional promotion piece (e.g. "q")
     */
    static AutoResponse autoMove(GameRecord record, Int from, Int to, String? promotion) {
        if (record.status != GameStatus.Ongoing || record.turn != Black) {
            return new AutoResponse(False, record, "Ready for a move");
        }

        if ((from | to) < 0) {
            // No legal moves available
            GameStatus status = checkGameStatus(record.board, Black);
            GameRecord updated = new GameRecord(
                record.board, record.turn, status,
                record.lastMove, record.playerScore, record.opponentScore,
                record.castlingRights, record.enPassantTarget, record.moveHistory,
                record.timeControl, record.halfMoveClock);
            return new AutoResponse(False, updated, "No legal moves");
        }

        // Apply the AI's move
        Char[] board = BoardUtils.cloneBoard(record.board);
        GameRecord updated = applyMove(record, board, from, to, promotion);
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
            if ('A' <= piece <= 'Z') {
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
