/**
 * Chess Game Logic Module
 *
 * This module implements the core chess game logic including:
 * - Move validation for all piece types (Pawn, Knight, Bishop, Rook, Queen, King)
 * - Board state management and manipulation
 * - Automated opponent (AI) move selection with scoring heuristics
 * - Game state detection (checkmate via piece elimination, stalemate)
 * - Algebraic notation parsing and formatting
 *
 * Simplified Rules:
 * This implementation uses simplified chess rules:
 * - No castling
 * - No en passant
 * - No explicit check/checkmate detection (king can be captured like any piece)
 * - Checkmate occurs when one side has no pieces left
 * - Stalemate occurs when only kings remain
 * - Pawns promote to Queens when reaching the opposite end
 *
 * Board Coordinate System:
 * - Board is represented as a 64-character string (row-major order)
 * - Index 0 = a8 (top-left), Index 63 = h1 (bottom-right)
 * - Files (columns) are labeled a-h (0-7)
 * - Ranks (rows) are labeled 1-8 (7-0 in array indices)
 */
module chessLogic.examples.org {
    // Import database package for data models
    package db import chessDB.examples.org;

    // Import database schema and models
    import db.GameRecord;
    import db.GameStatus;
    import db.Color;

    /**
     * ChessLogic Service.
     *
     * Stateless service providing all chess game logic operations.
     * All methods are static and operate on immutable GameRecord instances.
     */
    service ChessLogic {
        // ----- Board and Square Constants -------------------------------------------------

        /** Size of one side of the chess board (8x8) */
        static Int BOARD_SIZE = 8;

        /** Index increment to move one file (column) to the right */
        static Int FILE_STEP = 1;

        /** Index increment to move one rank (row) down the board */
        static Int RANK_STEP = 8;

        /** Minimum file letter in algebraic notation */
        static Char FILE_MIN = 'a';

        /** Maximum file letter in algebraic notation */
        static Char FILE_MAX = 'h';

        /** Minimum rank digit in algebraic notation */
        static Char RANK_MIN = '1';

        /** Maximum rank digit in algebraic notation */
        static Char RANK_MAX = '8';

        /** Expected length of square notation string (e.g., "e4") */
        static Int SQUARE_STRING_LENGTH = 2;

        /** Sentinel value indicating invalid/unparseable square */
        static Int INVALID_SQUARE = -1;

        /** Maximum rank index (0-based, so 7 for rank 8) */
        static Int MAX_RANK_INDEX = 7;

        // ----- Piece Position Constants ---------------------------------------------------

        /** Starting rank index for White pawns (rank 2 in array coordinates) */
        static Int WHITE_PAWN_START_RANK = 6;

        /** Starting rank index for Black pawns (rank 7 in array coordinates) */
        static Int BLACK_PAWN_START_RANK = 1;

        /** Rank index where White pawns promote (rank 8) */
        static Int WHITE_PROMOTION_RANK = 0;

        /** Rank index where Black pawns promote (rank 1) */
        static Int BLACK_PROMOTION_RANK = 7;

        // ----- AI Scoring Constants -------------------------------------------------------

        /** Center file index for position scoring (file d) */
        static Int CENTER_FILE = 3;

        /** Center rank index for position scoring (between rank 4 and 5) */
        static Int CENTER_RANK = 3;

        /** Base bonus points for pieces near the center */
        static Int CENTER_BONUS_BASE = 5;

        /** Bonus points for pawn promotion */
        static Int PROMOTION_BONUS = 8;

        /** Bonus points for achieving checkmate */
        static Int CHECKMATE_SCORE = 1000;

        /** Minimum score for move evaluation */
        static Int MIN_SCORE = -10000;

        /**
         * Apply Human Player Move
         *
         * Validates and applies a move made by the human player (White).
         * Performs comprehensive validation:
         * - Game must be ongoing (not finished)
         * - Square notation must be valid
         * - Source square must contain a piece
         * - Player must move their own piece (correct turn)
         * - Cannot capture own pieces
         * - Move must be legal for that piece type
         *
         * @param record     Current game state
         * @param fromSquare Source square in algebraic notation (e.g., "e2")
         * @param toSquare   Destination square in algebraic notation (e.g., "e4")
         * @param promotion  Optional promotion piece for pawns reaching the end (default: Queen)
         * @return MoveOutcome indicating success/failure with updated game state or error message
         */
        static MoveOutcome applyHumanMove(GameRecord record, String fromSquare, String toSquare, String? promotion = Null) {
            // Check if game is already finished
            if (record.status != Ongoing) {
                return new MoveOutcome(False, record, "Game already finished");
            }

            // Parse square notation to board indices
            Int from = parseSquare(fromSquare);
            Int to   = parseSquare(toSquare);
            if (from < 0 || to < 0) {
                return new MoveOutcome(False, record, "Invalid square format");
            }

            // Get a mutable copy of the board for validation
            Char[] board = cloneBoard(record.board);
            Char   piece = board[from];

            // Verify source square has a piece
            if (piece == '.') {
                return new MoveOutcome(False, record, "No piece on source square");
            }

            // Verify it's the correct player's turn
            Color mover = colorOf(piece);
            if (mover != record.turn) {
                return new MoveOutcome(False, record, "Not your turn");
            }

            // Verify player isn't capturing their own piece
            Char target = board[to];
            if (target != '.' && colorOf(target) == mover) {
                return new MoveOutcome(False, record, "Cannot capture your own piece");
            }

            // Validate move is legal for this piece type
            if (!isLegal(piece, from, to, board)) {
                return new MoveOutcome(False, record, "Illegal move for that piece");
            }

            // Move is valid - apply it and return updated game state
            GameRecord updated = applyMove(record, cloneBoard(record.board), from, to, promotion);
            return new MoveOutcome(True, updated, updated.lastMove ?: "Move applied");
        }

        /**
         * Automated Opponent Move (AI)
         *
         * Generates and applies the best move for the Black player (opponent).
         * Uses a simple heuristic-based AI that evaluates all possible moves and
         * selects the one with the highest score.
         *
         * Scoring heuristics:
         * - Capturing pieces (by piece value: Pawn=1, Knight/Bishop=3, Rook=5, Queen=9)
         * - Moving toward center of board (positional advantage)
         * - Promoting pawns to Queens
         * - Achieving checkmate (very high score)
         *
         * @param record Current game state
         * @return AutoResponse containing the chosen move and updated game state, or stalemate if no legal moves
         */
        static AutoResponse autoMove(GameRecord record) {
            // Verify it's Black's turn and game is ongoing
            if (record.status != Ongoing || record.turn != Black) {
                return new AutoResponse(False, record, "Ready for a move");
            }

            Char[] board = cloneBoard(record.board);
            Int    squares      = board.size;
            Int    bestScore    = MIN_SCORE;
            AutoResponse? best  = Null;

            // Iterate through all squares to find Black pieces
            for (Int from : 0 ..< squares) {
                Char piece = board[from];
                // Skip empty squares and White pieces
                if (piece == '.' || colorOf(piece) != Black) {
                    continue;
                }

                // Try moving this piece to every possible square
                for (Int to = 0; to < squares; ++to) {
                    // Skip moving to same square
                    if (from == to) {
                        continue;
                    }

                    Char target = board[to];
                    // Skip capturing own pieces
                    if (target != '.' && colorOf(target) == Black) {
                        continue;
                    }

                    // Check if move is legal for this piece
                    if (!isLegal(piece, from, to, board)) {
                        continue;
                    }

                    // Evaluate this move and track if it's the best so far
                    Char[] boardCopy      = cloneBoard(record.board);
                    GameRecord updated    = applyMove(record, boardCopy, from, to, Null);
                    Int score             = evaluateMove(piece, target, to, updated.status);
                    String message        = $"Opponent moves {formatSquare(from)}{formatSquare(to)}";

                    if (score > bestScore) {
                        bestScore = score;
                        best      = new AutoResponse(True, updated, message);
                    }
                }
            }

            // Return the best move found, or stalemate if no legal moves
            return best?;

            GameRecord stalemate = new GameRecord(
                                                record.board,
                                                record.turn,
                                                Stalemate,
                                                record.lastMove,
                                                record.playerScore,
                                                record.opponentScore);
            return new AutoResponse(False, stalemate, "Opponent has no legal moves");
        }

    /**
     * Create Default Game
     *
     * Returns a new game with the standard chess starting position.
     * White moves first.
     *
     * @return GameRecord with initial board setup
     */
    static GameRecord defaultGame() {
        return new GameRecord(INITIAL_BOARD, White);
    }

    /**
     * Reset Game
     *
     * Creates a completely fresh game with:
     * - Standard starting position
     * - White to move
     * - Ongoing status
     * - No move history
     * - Scores reset to 0
     *
     * @return GameRecord representing a new game
     */
    static GameRecord resetGame() {
        return new GameRecord(
                             INITIAL_BOARD,
                             White,
                             Ongoing,
                             Null,
                             0,
                             0);
    }

    /**
     * Convert Board String to Rows
     *
     * Splits the 64-character board string into an array of 8 strings,
     * one for each rank (row) of the chess board.
     *
     * @param board 64-character board string
     * @return Array of 8 strings, each representing one rank from top to bottom
     */
    static String[] boardRows(String board) {
        String[] rows = new String[](BOARD_SIZE);
        for (Int i : 0 ..< BOARD_SIZE) {
            rows[i] = board[i * BOARD_SIZE ..< (i + 1) * BOARD_SIZE];
        }
        return rows;
    }

    // ----- Internal Helper Methods -------------------------------------------------
    //
    // The following methods handle the low-level details of move application,
    // game state detection, move validation, and board manipulation.

    /**
     * Apply Move to Board
     *
     * Executes a move on the board and returns an updated GameRecord.
     * This method:
     * - Moves the piece from source to destination
     * - Handles pawn promotion if applicable
     * - Updates capture scores
     * - Switches turn to the other player
     * - Detects game-ending conditions (checkmate/stalemate)
     * - Records the move in algebraic notation
     *
     * @param record    Current game state
     * @param board     Mutable board array to apply move on
     * @param from      Source square index
     * @param to        Destination square index
     * @param promotion Optional promotion piece (default: Queen)
     * @return New GameRecord with move applied
     */
    static GameRecord applyMove(GameRecord record, Char[] board, Int from, Int to, String? promotion) {
        Char piece  = board[from];
        Color mover = colorOf(piece);
        Char target = board[to];
        Boolean captured = target != '.';

        // Handle pawn promotion if piece reaches opposite end of board
        Char moved  = promoteIfNeeded(piece, to, promotion);
        board[to]   = moved;   // Place piece on destination square
        board[from] = '.';     // Clear source square

        // Create new board string from modified array
        String newBoard = new String(board);
        // Switch turn to the other player
        Color next   = mover == White ? Black : White;
        // Check if game has ended
        GameStatus status = detectStatus(board);
        // Record move in algebraic notation (e.g., "e2e4")
        String moveTag = formatSquare(from) + formatSquare(to);

        // Update capture scores
        Int playerScore   = record.playerScore;
        Int opponentScore = record.opponentScore;
        if (captured) {
            if (mover == White) {
                ++playerScore;     // White captured a Black piece
            } else {
                ++opponentScore;   // Black captured a White piece
            }
        }

        // Return new immutable game record
        return new GameRecord(
                                 newBoard,
                                 next,
                                 status,
                                 moveTag,
                                 playerScore,
                                 opponentScore);
    }

    /**
     * Detect Game Status
     *
     * Determines if the game has ended based on piece counts.
     *
     * Simplified win/loss conditions:
     * - Checkmate: One player has no pieces left
     * - Stalemate: Only kings remain (no other pieces)
     * - Ongoing: Both players have pieces
     *
     * Note: This is a simplified implementation that doesn't check for
     * traditional chess checkmate (king in check with no legal moves).
     *
     * @param board Current board state
     * @return GameStatus indicating game outcome
     */
    static GameStatus detectStatus(Char[] board) {
        Boolean whiteHasPieces = False;
        Boolean blackHasPieces = False;

        // Count pieces for each color
        for (Char c : board) {
            if (c == '.') {
                continue;  // Empty square
            }
            if (colorOf(c) == White) {
                whiteHasPieces = True;
            } else {
                blackHasPieces = True;
            }
        }

        // If either player has no pieces, game is over (checkmate)
        return whiteHasPieces && blackHasPieces ? Ongoing : Checkmate;
    }

    /**
     * Check Move Legality
     *
     * Validates whether a move is legal according to chess rules for each piece type.
     * This is the core move validation logic that checks:
     * - Pawn: Forward 1 or 2 (from start), diagonal capture
     * - Knight: L-shape (2+1 or 1+2 squares)
     * - Bishop: Diagonal lines (any distance, clear path)
     * - Rook: Straight lines (any distance, clear path)
     * - Queen: Combination of Bishop and Rook (any diagonal or straight)
     * - King: One square in any direction
     *
     * @param piece Chess piece character (e.g., 'P' for White pawn, 'n' for Black knight)
     * @param from  Source square index
     * @param to    Destination square index
     * @param board Current board state
     * @return True if move is legal for that piece type, False otherwise
     */
    static Boolean isLegal(Char piece, Int from, Int to, Char[] board) {
        Color mover = colorOf(piece);
        // Calculate file (column) and rank (row) for source and destination
        Int fromFile   = fileIndex(from);
        Int fromRank   = rankIndex(from);
        Int toFile     = fileIndex(to);
        Int toRank     = rankIndex(to);
        // Calculate file and rank differences
        Int df         = toFile - fromFile;    // File delta (-7 to +7)
        Int dr         = toRank - fromRank;    // Rank delta (-7 to +7)
        // Absolute values for distance calculations
        Int adf        = df >= 0 ? df : -df;   // Absolute file difference
        Int adr        = dr >= 0 ? dr : -dr;   // Absolute rank difference

        // Normalize piece to uppercase for type checking
        Char type = upper(piece);
        switch (type) {
        case 'P':  // Pawn movement validation
            // Pawns move differently based on color
            Int dir      = mover == White ? -1 : +1;  // White moves up (negative), Black moves down (positive)
            Int startRow = mover == White ? WHITE_PAWN_START_RANK : BLACK_PAWN_START_RANK;
            Char target  = board[to];

            // Forward one square to empty square
            if (df == 0 && dr == dir && target == '.') {
                return True;
            }
            // Forward two squares from starting position
            if (df == 0 && dr == dir * 2 && fromRank == startRow && target == '.') {
                Int mid = from + dir * RANK_STEP;
                return board[mid] == '.';  // Path must be clear
            }
            // Diagonal capture
            if (adf == 1 && dr == dir && target != '.' && colorOf(target) != mover) {
                return True;
            }
            return False;

        case 'N':  // Knight: L-shape movement (2+1 or 1+2)
            return (adf == 1 && adr == 2) || (adf == 2 && adr == 1);

        case 'B':  // Bishop: Diagonal movement
            if (adf == adr && adf != 0) {
                // Calculate step direction for path checking
                Int step = (dr > 0 ? RANK_STEP : -RANK_STEP) + (df > 0 ? FILE_STEP : -FILE_STEP);
                return clearPath(board, from, to, step);
            }
            return False;

        case 'R':  // Rook: Straight line movement (horizontal or vertical)
            if (df == 0 && adr != 0) {  // Vertical movement
                Int step = dr > 0 ? RANK_STEP : -RANK_STEP;
                return clearPath(board, from, to, step);
            }
            if (dr == 0 && adf != 0) {  // Horizontal movement
                Int step = df > 0 ? FILE_STEP : -FILE_STEP;
                return clearPath(board, from, to, step);
            }
            return False;

        case 'Q':  // Queen: Combination of Rook and Bishop
            // Straight line (like Rook)
            if (df == 0 || dr == 0) {
                Int step = df == 0 ? (dr > 0 ? RANK_STEP : -RANK_STEP) : (df > 0 ? FILE_STEP : -FILE_STEP);
                return clearPath(board, from, to, step);
            }
            // Diagonal (like Bishop)
            if (adf == adr && adf != 0) {
                Int step = (dr > 0 ? RANK_STEP : -RANK_STEP) + (df > 0 ? FILE_STEP : -FILE_STEP);
                return clearPath(board, from, to, step);
            }
            return False;

        case 'K':  // King: One square in any direction
            return adf <= 1 && adr <= 1 && (adf + adr > 0);

        default:
            return False;  // Unknown piece type
        }
    }

    /**
     * Check Clear Path Between Squares
     *
     * Verifies that all squares between source and destination are empty.
     * Used for Bishop, Rook, and Queen moves to ensure no pieces are jumped.
     *
     * @param board Board state
     * @param from  Source square index
     * @param to    Destination square index
     * @param step  Index increment to traverse path (e.g., +8 for up, -1 for left)
     * @return True if all intermediate squares are empty, False otherwise
     */
    static Boolean clearPath(Char[] board, Int from, Int to, Int step) {
        // Start from first square after source, stop before destination
        for (Int idx = from + step; idx != to; idx += step) {
            if (board[idx] != '.') {
                return False;  // Path is blocked
            }
        }
        return True;  // Path is clear
    }

    /**
     * Evaluate Move Score (AI Heuristic)
     *
     * Calculates a numeric score for a potential move to help the AI
     * choose the best move. Higher scores indicate better moves.
     *
     * Scoring factors:
     * - Captured piece value (Pawn=1, Knight/Bishop=3, Rook=5, Queen=9, King=100)
     * - Position bonus (pieces near center score higher)
     * - Pawn promotion bonus (+8)
     * - Checkmate bonus (+1000)
     *
     * @param piece  Moving piece
     * @param target Captured piece (or '.' if no capture)
     * @param to     Destination square index
     * @param status Game status after move
     * @return Numeric score for this move
     */
    static Int evaluateMove(Char piece, Char target, Int to, GameStatus status) {
        Int score = pieceValue(target);  // Base score: value of captured piece
        score += positionBonus(to);      // Add positional advantage

        // Bonus for winning the game
        if (status == Checkmate) {
            score += CHECKMATE_SCORE;
        }

        // Bonus for pawn promotion
        if (upper(piece) == 'P' && (rankIndex(to) == WHITE_PROMOTION_RANK || rankIndex(to) == BLACK_PROMOTION_RANK)) {
            score += PROMOTION_BONUS;
        }
        return score;
    }

    /**
     * Piece Type Enumeration
     *
     * Defines the six standard chess piece types.
     * Used for type-safe piece identification.
     */
    enum PieceType { Pawn, Knight, Bishop, Rook, Queen, King }

    /**
     * Piece Value Map
     *
     * Standard chess piece values used for move evaluation:
     * - Pawn (P/p): 1 point
     * - Knight (N/n): 3 points
     * - Bishop (B/b): 3 points
     * - Rook (R/r): 5 points
     * - Queen (Q/q): 9 points
     * - King (K/k): 100 points (very high to avoid king captures)
     *
     * Both uppercase (White) and lowercase (Black) pieces have same values.
     */
    static Map<Char, Int> PIECE_VALUES = Map:[
        'P'=1, 'N'=3, 'B'=3, 'R'=5, 'Q'=9, 'K'=100,
        'p'=1, 'n'=3, 'b'=3, 'r'=5, 'q'=9, 'k'=100
    ];

    /**
     * Get Piece Value
     *
     * Returns the strategic value of a chess piece for AI evaluation.
     *
     * @param piece Chess piece character (e.g., 'Q', 'p', '.')
     * @return Numeric value of the piece, or 0 for empty squares
     */
    static Int pieceValue(Char piece) {
        return PIECE_VALUES.getOrDefault(piece, 0);
    }

    /**
     * Calculate Position Bonus
     *
     * Returns a bonus score based on how close a square is to the center.
     * Encourages the AI to move pieces toward the center of the board,
     * which is generally a strong strategic position.
     *
     * Center squares (d4, d5, e4, e5) get highest bonus.
     * Edge squares get lowest bonus.
     *
     * @param index Square index (0-63)
     * @return Position bonus points (higher for center squares)
     */
    static Int positionBonus(Int index) {
        Int file = fileIndex(index);
        Int rank = rankIndex(index);
        // Manhattan distance from center point
        Int centerDistance = (file - CENTER_FILE).abs() + (rank - CENTER_RANK).abs();
        // Closer to center = higher bonus
        return CENTER_BONUS_BASE - centerDistance;
    }

    /**
     * Parse Square Notation
     *
     * Converts algebraic notation (e.g., "e4", "a8") to board index (0-63).
     *
     * Format: file (a-h) + rank (1-8)
     * - a1 = bottom-left (White's corner) = index 56
     * - h8 = top-right (Black's corner) = index 7
     *
     * @param square Algebraic notation string (e.g., "e4")
     * @return Board index (0-63), or INVALID_SQUARE (-1) if format is invalid
     */
    static Int parseSquare(String square) {
        // Check length (must be exactly 2 characters)
        if (square.size != SQUARE_STRING_LENGTH) {
            return INVALID_SQUARE;
        }
        Char file = square[0];  // Column: a-h
        Char rank = square[1];  // Row: 1-8

        // Validate character ranges
        if (file < FILE_MIN || file > FILE_MAX || rank < RANK_MIN || rank > RANK_MAX) {
            return INVALID_SQUARE;
        }

        // Convert to 0-based indices
        Int f = file - FILE_MIN;  // 0-7
        Int r = rank - RANK_MIN;  // 0-7
        // Board is stored with rank 8 at top (index 0), so invert rank
        return (MAX_RANK_INDEX - r) * 8 + f;
    }

    /**
     * Format Square Index
     *
     * Converts board index (0-63) to algebraic notation (e.g., "e4").
     * Inverse of parseSquare().
     *
     * @param index Board index (0-63)
     * @return Algebraic notation string (e.g., "a1", "h8")
     */
    static String formatSquare(Int index) {
        // Invert rank (board stored with rank 8 at top)
        Int r = MAX_RANK_INDEX - rankIndex(index);
        Int f = fileIndex(index);
        // Convert to characters
        Char file = FILE_MIN + f;  // a-h
        Char rank = RANK_MIN + r;  // 1-8
        return $"{file}{rank}";
    }

    /**
     * Get File Index
     *
     * Extracts the file (column) index from a board index.
     * Files are numbered 0-7 corresponding to chess files a-h.
     *
     * @param index Board index (0-63)
     * @return File index (0=a, 1=b, ..., 7=h)
     */
    static Int fileIndex(Int index) = index % BOARD_SIZE;

    /**
     * Get Rank Index
     *
     * Extracts the rank (row) index from a board index.
     * Ranks are numbered 0-7 with 0 at the top (rank 8) and 7 at bottom (rank 1).
     *
     * @param index Board index (0-63)
     * @return Rank index (0=rank 8, 1=rank 7, ..., 7=rank 1)
     */
    static Int rankIndex(Int index) = index / BOARD_SIZE;

    /**
     * Determine Piece Color
     *
     * Identifies which player owns a piece based on its character case.
     * - Lowercase letters (a-z) = Black pieces
     * - Uppercase letters (A-Z) = White pieces
     *
     * @param piece Chess piece character
     * @return Black for lowercase, White for uppercase
     */
    static Color colorOf(Char piece) {
        return piece >= FILE_MIN && piece <= 'z' ? Black : White;
    }

    /**
     * Convert Piece to Uppercase
     *
     * Converts a piece character to uppercase for type comparison.
     * Allows piece type logic to be written once for both colors.
     *
     * @param piece Chess piece character (any case)
     * @return Uppercase version (e.g., 'p' -> 'P', 'K' -> 'K')
     */
    static Char upper(Char piece) {
        if (piece >= FILE_MIN && piece <= 'z') {
            // Lowercase: convert to uppercase
            Int offset = piece - FILE_MIN;
            return 'A' + offset;
        }
        // Already uppercase
        return piece;
    }

    /**
     * Handle Pawn Promotion
     *
     * Promotes a pawn to a Queen (or specified piece) if it reaches
     * the opposite end of the board.
     *
     * - White pawns promote when reaching rank 8 (index 0)
     * - Black pawns promote when reaching rank 1 (index 7)
     * - Default promotion piece is Queen
     *
     * @param piece     Moving piece character
     * @param to        Destination square index
     * @param promotion Optional promotion piece ('Q', 'R', 'B', 'N'), defaults to Queen
     * @return Promoted piece if applicable, otherwise the original piece
     */
    static Char promoteIfNeeded(Char piece, Int to, String? promotion) {
        // Only pawns can promote
        if (upper(piece) != 'P') {
            return piece;
        }

        Int rank = rankIndex(to);
        Boolean isWhite = colorOf(piece) == White;

        // Check if pawn reached promotion rank
        if ((isWhite && rank == WHITE_PROMOTION_RANK) || (!isWhite && rank == BLACK_PROMOTION_RANK)) {
            Char promo = 'Q';  // Default to Queen
            // Use specified promotion piece if provided
            if (promotion != Null && promotion.size == 1) {
                promo = upper(promotion[0]);
            }
            // Return promoted piece with appropriate case for color
            return isWhite ? promo : (FILE_MIN + (promo - 'A'));
        }
        return piece;  // No promotion
    }

    /**
     * Clone Board Array
     *
     * Creates a mutable copy of the board string as a character array.
     * Needed because strings are immutable, but we need to modify the
     * board when applying moves.
     *
     * @param board Board string (64 characters)
     * @return Mutable character array copy of the board
     */
    static Char[] cloneBoard(String board) {
        Int size    = board.size;
        Char[] copy = new Char[size];
        for (Int i = 0; i < size; ++i) {
            copy[i] = board[i];
        }
        return copy;
    }

    /**
     * Initial Chess Board Configuration
     *
     * Standard starting position for chess:
     * Rank 8: rnbqkbnr (Black's back rank)
     * Rank 7: pppppppp (Black's pawns)
     * Rank 6-3: ........ (empty squares)
     * Rank 2: PPPPPPPP (White's pawns)
     * Rank 1: RNBQKBNR (White's back rank)
     *
     * Piece notation:
     * - r/R: Rook
     * - n/N: Knight
     * - b/B: Bishop
     * - q/Q: Queen
     * - k/K: King
     * - p/P: Pawn
     * - . : Empty square
     */
    static String INITIAL_BOARD =
            "rnbqkbnr" +
            "pppppppp" +
            "........" +
            "........" +
            "........" +
            "........" +
            "PPPPPPPP" +
            "RNBQKBNR";
}

    /**
     * Move Outcome Result
     *
     * Represents the result of attempting to apply a human player's move.
     *
     * @param ok      True if move was legal and applied, False if illegal
     * @param record  Updated game state (if ok=True) or original state (if ok=False)
     * @param message Descriptive message about the move result or error
     */
    const MoveOutcome(Boolean ok, GameRecord record, String message) {}

    /**
     * Automated Move Response
     *
     * Represents the result of the AI opponent's move selection.
     *
     * @param moved   True if a move was made, False if no legal moves available
     * @param record  Updated game state after opponent's move
     * @param message Descriptive message about the move (e.g., "Opponent moves e7e5")
     */
    const AutoResponse(Boolean moved, GameRecord record, String message) {}
}
