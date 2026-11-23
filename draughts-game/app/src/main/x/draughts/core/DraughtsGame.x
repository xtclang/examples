import db.models.Color;
import db.models.GameStatus;
import db.models.GameRecord;
import db.models.MoveEntry;
import db.models.ScoreEntry;
import core.DraughtsRules.Move;

/**
 * DraughtsGame - game state management on top of the rules.
 *
 * Starts games, applies a player's move to a GameRecord (validating it against the rules), and
 * works out who won. It has no idea about HTTP; DraughtsApi wraps it.
 */
service DraughtsGame {
    /**
     * The longest nickname kept.
     */
    static Int MAX_NAME = 20;

    /**
     * What came of trying a move.
     *
     * @param ok       True if the move was legal and has been applied
     * @param record   The game after the move, or unchanged if it was refused
     * @param message  Why the move was refused, or a description of the move that was played
     */
    static const MoveOutcome(Boolean ok, GameRecord record, String message);

    /**
     * A new game in the starting position. Black moves first.
     */
    static GameRecord newGame(String blackName = "Black", String whiteName = "White") {
        return new GameRecord(DraughtsRules.startingBoard(), Black, Ongoing,
                              cleanName(blackName, "Black"), cleanName(whiteName, "White"));
    }

    /**
     * A nickname with the surrounding space removed and its length limited, or the fallback if
     * nothing is left.
     */
    static String cleanName(String? name, String fallback) {
        String text = (name ?: "").trim();
        if (text.size > MAX_NAME) {
            text = text[0 ..< MAX_NAME].trim();
        }
        return text.empty ? fallback : text;
    }

    /**
     * Play a move, given as the path the piece takes ("c3-d4", or "c3-e5-g7" for a double jump).
     * The path must match one of the legal moves exactly.
     */
    static MoveOutcome applyMove(GameRecord record, String pathText) {
        if (record.status != Ongoing) {
            return new MoveOutcome(False, record, "Game already finished");
        }

        Int[] path = DraughtsRules.parsePath(pathText);
        if (path.size < 2) {
            return new MoveOutcome(False, record, "Invalid square format");
        }

        Move move;
        if (!(move := DraughtsRules.findMove(record.board, record.turn, path))) {
            Boolean mustCapture = DraughtsRules.legalMoves(record.board, record.turn)[0].captures.size > 0;
            return new MoveOutcome(False, record, mustCapture
                    ? "Illegal move: you must capture."
                    : "Illegal move");
        }

        (String board, Boolean crowned) = DraughtsRules.applyMove(record.board, move);
        Color  next       = DraughtsRules.opponent(record.turn);
        Char   piece      = record.board[path[0]];

        // The draw counter resets whenever something irreversible happens.
        Boolean progress    = move.captures.size > 0 || !DraughtsRules.isKing(piece);
        Int     quietPlies  = progress ? 0 : record.quietPlies + 1;
        GameStatus status   = DraughtsRules.statusOf(board, next, quietPlies);

        MoveEntry entry = new MoveEntry(record.history.size + 1, record.turn, move.pathText,
                                        move.captures.size, crowned, move.notation, board);

        GameRecord updated = new GameRecord(board, next, status, record.blackName, record.whiteName,
                                            quietPlies, move.pathText, record.history + entry);
        return new MoveOutcome(True, updated, move.notation);
    }

    /**
     * The result of a finished game as the winner's color, or Null for a draw.
     */
    static Color? winnerOf(GameStatus status) {
        return switch (status) {
            case BlackWins: Black;
            case WhiteWins: White;
            default: Null;
        };
    }

    /**
     * The board as 8 strings, one per row, row 0 (the top of the screen) first.
     */
    static String[] boardRows(String board) {
        return new Array<String>(8, i -> board[i * 8 ..< (i + 1) * 8]);
    }

    /**
     * The scoreboard key for a player on a given day.
     */
    static String scoreKey(String date, String name) = $"{date}|{name}";
}
