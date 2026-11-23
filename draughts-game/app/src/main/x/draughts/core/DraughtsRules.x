import db.models.Color;
import db.models.GameStatus;

/**
 * DraughtsRules - the rules of English draughts (checkers).
 *
 * This knows nothing about HTTP or the database. It only answers "what moves are legal?" and
 * "what does the board look like after this move?".
 *
 * The board is a 64-character string in row-major order; row 0 is the top of the screen.
 *   '.' empty    'b' Black man   'B' Black king   'w' White man   'W' White king
 * Black starts at the bottom (rows 5-7) and moves up; White starts at the top (rows 0-2) and
 * moves down. Only dark squares ((row + column) odd) are used.
 *
 * Squares are named like chess squares: a-h for the column, 8 down to 1 for the row, so index 0
 * is "a8" and index 56 is "a1".
 *
 * The rules:
 * - men move one square diagonally forward; kings move diagonally both ways
 * - a capture jumps an adjacent enemy piece onto the empty square beyond it
 * - captures are compulsory, and a capturing piece must keep jumping while it can
 * - a man reaching the far row is crowned, and its move ends there
 * - a player with no legal move loses
 * - a game with 40 moves each and no capture or man moved is drawn (house rule)
 */
service DraughtsRules {
    static Int SIZE = 8;

    /**
     * The game is drawn after this many half-moves with no capture and no man moved.
     */
    static Int DRAW_LIMIT = 80;

    /**
     * A legal move: the squares the piece visits (the first is where it starts, the last where
     * it ends), and the squares of the pieces it captures along the way.
     */
    static const Move(Int[] path, Int[] captures) {
        /**
         * The path as the client sees it, e.g. "c3-e5-g7".
         */
        String pathText.get() {
            StringBuffer buf = new StringBuffer();
            for (Int square : path) {
                if (buf.size > 0) {
                    buf.append('-');
                }
                buf.append(DraughtsRules.toAlgebraic(square));
            }
            return buf.toString();
        }

        /**
         * Display notation: "c3-d4" for a step, "c3xe5xg7" for a capture.
         */
        String notation.get() {
            StringBuffer buf = new StringBuffer();
            for (Int square : path) {
                if (buf.size > 0) {
                    buf.append(captures.empty ? '-' : 'x');
                }
                buf.append(DraughtsRules.toAlgebraic(square));
            }
            return buf.toString();
        }
    }

    // ----- Squares -----------------------------------------------------------

    /**
     * The starting position: White on the top three rows, Black on the bottom three.
     */
    static String startingBoard() {
        Char[] board = new Char[64](i -> {
            Int row = i / SIZE;
            Int col = i % SIZE;
            if ((row + col) % 2 == 1) {
                if (row < 3) {
                    return 'w';
                }
                if (row > 4) {
                    return 'b';
                }
            }
            return '.';
        });
        return new String(board);
    }

    /**
     * Parse a square name ("c3") to a board index, or -1 if it is not a square.
     */
    static Int parseSquare(String square) {
        if (square.size != 2) {
            return -1;
        }
        Char file = square[0];
        Char rank = square[1];
        if (file < 'a' || file > 'h' || rank < '1' || rank > '8') {
            return -1;
        }
        return ('8' - rank).toInt() * SIZE + (file - 'a').toInt();
    }

    /**
     * A board index as a square name.
     */
    static String toAlgebraic(Int index) {
        Char file = ('a'.toInt() + index % SIZE).toChar();
        Char rank = ('8'.toInt() - index / SIZE).toChar();
        return $"{file}{rank}";
    }

    /**
     * Parse "c3-e5-g7" into board indexes, or an empty array if any part is not a square.
     */
    static Int[] parsePath(String text) {
        Int[] path = new Array<Int>();
        for (String part : text.split('-')) {
            Int square = parseSquare(part);
            if (square < 0) {
                return [];
            }
            path.add(square);
        }
        return path.freeze(inPlace=True);
    }

    // ----- Pieces ------------------------------------------------------------

    static Boolean isKing(Char piece) = piece == 'B' || piece == 'W';

    /**
     * Who owns a piece, or Null for an empty square.
     */
    static Color? ownerOf(Char piece) {
        return switch (piece) {
            case 'b', 'B': Black;
            case 'w', 'W': White;
            default: Null;
        };
    }

    static Color opponent(Color player) = player == Black ? White : Black;

    /**
     * The row on which a player's men are crowned.
     */
    static Int crowningRow(Color player) = player == Black ? 0 : SIZE - 1;

    /**
     * A row step of -1 moves up the screen (Black's forward), +1 moves down (White's).
     */
    private static Boolean mayMove(Char piece, Int rowStep) {
        return isKing(piece) || (ownerOf(piece) == Black ? rowStep < 0 : rowStep > 0);
    }

    private static Boolean onBoard(Int row, Int col) = 0 <= row < SIZE && 0 <= col < SIZE;

    // ----- Moves -------------------------------------------------------------

    /**
     * Every capture sequence for the piece on `from`. A capturing piece must keep jumping while
     * it can, so each result is a maximal chain; a man crowned mid-chain stops there.
     *
     * Captured pieces come off the board as they are jumped, so a piece cannot be jumped twice,
     * and the square the piece left can be landed on again.
     */
    private static Move[] captureSequences(Char[] board, Int from, Char piece,
                                           Int[] path, Int[] captured) {
        Color    mover   = ownerOf(piece).as(Color);
        Move[]   results = new Array<Move>();
        Int      row     = from / SIZE;
        Int      col     = from % SIZE;

        for (Int rowStep : [-1, 1]) {
            if (!mayMove(piece, rowStep)) {
                continue;
            }
            for (Int colStep : [-1, 1]) {
                Int landRow = row + 2 * rowStep;
                Int landCol = col + 2 * colStep;
                if (!onBoard(landRow, landCol)) {
                    continue;
                }
                Int mid  = (row + rowStep) * SIZE + col + colStep;
                Int land = landRow * SIZE + landCol;
                if (ownerOf(board[mid]) != opponent(mover) || board[land] != '.') {
                    continue;
                }

                // Make the jump on a copy of the board, then look for more jumps.
                Char[] next = BoardCopy.of(board);
                next[from] = '.';
                next[mid]  = '.';
                next[land] = piece;
                Int[] newPath     = path + land;
                Int[] newCaptured = captured + mid;

                Boolean crowned = !isKing(piece) && landRow == crowningRow(mover);
                Move[]  more    = crowned
                        ? []
                        : captureSequences(next, land, piece, newPath, newCaptured);
                if (more.empty) {
                    results.add(new Move(newPath, newCaptured));
                } else {
                    results.addAll(more);
                }
            }
        }
        return results.freeze(inPlace=True);
    }

    /**
     * Every legal move for the player to move. If any capture exists, only captures are legal.
     */
    static Move[] legalMoves(String boardText, Color turn) {
        Char[] board    = BoardCopy.of(boardText);
        Move[] captures = new Array<Move>();
        Move[] steps    = new Array<Move>();

        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (ownerOf(piece) != turn) {
                continue;
            }
            captures.addAll(captureSequences(board, from, piece, [from], []));

            Int row = from / SIZE;
            Int col = from % SIZE;
            for (Int rowStep : [-1, 1]) {
                if (!mayMove(piece, rowStep)) {
                    continue;
                }
                for (Int colStep : [-1, 1]) {
                    Int toRow = row + rowStep;
                    Int toCol = col + colStep;
                    if (onBoard(toRow, toCol) && board[toRow * SIZE + toCol] == '.') {
                        steps.add(new Move([from, toRow * SIZE + toCol], []));
                    }
                }
            }
        }
        return (captures.empty ? steps : captures).freeze(inPlace=True);
    }

    /**
     * The legal move that follows exactly this path, if there is one.
     */
    static conditional Move findMove(String board, Color turn, Int[] path) {
        for (Move move : legalMoves(board, turn)) {
            if (move.path == path) {
                return True, move;
            }
        }
        return False;
    }

    /**
     * The board after a move. The old board is not changed.
     *
     * @return the new board, and whether the move crowned a man
     */
    static (String, Boolean) applyMove(String boardText, Move move) {
        Char[] board = BoardCopy.of(boardText);
        Int    from  = move.path[0];
        Int    to    = move.path[move.path.size - 1];
        Char   piece = board[from];

        board[from] = '.';
        for (Int captured : move.captures) {
            board[captured] = '.';
        }

        Boolean crowned = !isKing(piece) && to / SIZE == crowningRow(ownerOf(piece).as(Color));
        board[to] = crowned ? (piece == 'b' ? 'B' : 'W') : piece;
        return new String(board), crowned;
    }

    /**
     * How many pieces a player has (men and kings).
     */
    static Int countPieces(String board, Color player) {
        Int count = 0;
        for (Char piece : board) {
            if (ownerOf(piece) == player) {
                ++count;
            }
        }
        return count;
    }

    /**
     * The result of a position with `turn` to move: Ongoing while play continues.
     */
    static GameStatus statusOf(String board, Color turn, Int quietPlies) {
        if (quietPlies >= DRAW_LIMIT) {
            return Draw;
        }
        if (legalMoves(board, turn).empty) {
            // The player who cannot move loses.
            return turn == Black ? WhiteWins : BlackWins;
        }
        return Ongoing;
    }

    /**
     * Copies a board, from either its text or another array, into a fresh mutable array.
     */
    static service BoardCopy {
        static Char[] of(String board) = new Char[64](i -> board[i]);
        static Char[] of(Char[] board)  = new Char[64](i -> board[i]);
    }
}
