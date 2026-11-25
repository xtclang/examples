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
     *
     * @param level  "" for two players at one screen; "easy", "medium" or "hard" to play the
     *               computer, which is White and is named after its level
     */
    static GameRecord newGame(String blackName = "Black", String whiteName = "White",
                              String level = "") {
        String chosen = normalizeLevel(level);
        String white  = chosen.empty
                ? cleanName(whiteName, "White")
                : $"Computer ({DraughtsAi.levelFor(chosen).label})";
        return new GameRecord(DraughtsRules.startingBoard(), Black, Ongoing,
                              cleanName(blackName, "Black"), white, 0, Null, [], chosen);
    }

    /**
     * A level name the game understands: "easy", "medium" or "hard", or "" for no computer. A
     * level that is not recognised is taken as medium.
     */
    static String normalizeLevel(String? level) {
        String text = (level ?: "").trim();
        return text.empty ? "" : DraughtsAi.levelFor(text).name;
    }

    /**
     * True if the computer is to move: it plays White, in a game that has a level.
     */
    static Boolean computerToMove(GameRecord record) {
        return !record.level.empty && record.status == Ongoing && record.turn == White;
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
        if (computerToMove(record)) {
            return new MoveOutcome(False, record, "It is the computer's turn");
        }
        return play(record, pathText);
    }

    /**
     * Play the computer's move, chosen by DraughtsAi at the game's level.
     */
    static MoveOutcome applyComputerMove(GameRecord record, Random random) {
        if (record.status != Ongoing) {
            return new MoveOutcome(False, record, "Game already finished");
        }
        if (!computerToMove(record)) {
            return new MoveOutcome(False, record, "It is not the computer's turn");
        }
        Move move;
        if (!(move := DraughtsAi.chooseMove(record.board, record.turn, record.level, random))) {
            return new MoveOutcome(False, record, "The computer has no legal move");
        }
        return play(record, move.pathText);
    }

    /**
     * Apply a move for whoever is to move, once it is known to be theirs to make.
     */
    private static MoveOutcome play(GameRecord record, String pathText) {

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
                                            quietPlies, move.pathText, record.history + entry,
                                            record.level);
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
     * A human-readable description of the game for the status line.
     */
    static String describeState(GameRecord game, Boolean mustCapture) {
        switch (game.status) {
        case BlackWins:
            return $"{game.blackName} (Black) wins: {game.whiteName} has no legal moves left.";
        case WhiteWins:
            return $"{game.whiteName} (White) wins: {game.blackName} has no legal moves left.";
        case Draw:
            return "Draw: 40 moves each without a capture or a man moving.";
        default:
            break;
        }
        if (computerToMove(game)) {
            return $"{game.whiteName} is thinking...";
        }
        String name = game.turn == Black ? game.blackName : game.whiteName;
        return mustCapture ? $"{name} to move - you must capture." : $"{name} to move.";
    }

    /**
     * The board as 8 strings, one per row, row 0 (the top of the screen) first.
     */
    static String[] boardRows(String board) {
        return new Array<String>(8, i -> board[i * 8 ..< (i + 1) * 8]);
    }

    /**
     * The scoreboard key for a player in a scoreboard's scope (see Scoreboard).
     */
    static String scoreKey(String scope, String name) = $"{scope}|{name}";
}
