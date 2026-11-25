import db.models.CastlingRights;
import db.models.MoveHistoryEntry;
import validation.CheckDetection;
import validation.CheckDetection.MovePair;
import core.ChessGame.MoveOutcome;

/**
 * Replays a PGN movetext (SAN moves, e.g. "1. e4 e5 2. Nf3 ...") from a starting FEN, producing
 * the per-move frames the frontend needs for stepping through a chess.com game or puzzle.
 *
 * This exists because [ChessComApi] is a pure pass-through proxy to chess.com and never parses
 * PGN -- the chess.com responses carry PGN text, and resolving each SAN token to the from/to
 * squares [ChessLogic.applyHumanMove] expects requires knowing the legal moves of the position,
 * which only the backend's chess rules (here, [CheckDetection.getAllLegalMoves]) can answer.
 */
@Abstract
class PgnReplay {
    /**
     * One position in the replay: the start position, or the position just after a move.
     */
    static const Frame(String fen,
                       String board,
                       Color? color = Null,
                       String? fromSquare = Null,
                       String? toSquare = Null,
                       String? promotion = Null,
                       String? notation = Null,
                       Boolean isCheck = False,
                       Boolean isCheckmate = False);

    /**
     * Replays `pgn` from `startFen`, returning one [Frame] per position (the start position,
     * then one more per move actually applied). If a SAN token cannot be resolved to a unique
     * legal move, replay stops there and the frames collected so far are returned -- the same
     * defensive behavior the frontend's own replay used to have.
     */
    static Frame[] replay(String startFen, String pgn) {
        GameRecord record = FenParser.fromFen(startFen);
        Boolean startInCheck = CheckDetection.isInCheck(record.board, record.turn);
        Frame[] frames = [new Frame(startFen, record.board, isCheck = startInCheck)];

        for (String token : tokenize(pgn)) {
            if ((Int from, Int to, String? promotion) := resolveSan(token, record.board, record.turn,
                    record.castlingRights, record.enPassantTarget)) {
                MoveOutcome outcome = ChessLogic.applyHumanMove(record,
                        BoardUtils.toAlgebraic(from), BoardUtils.toAlgebraic(to), promotion);
                if (!outcome.ok) {
                    break;
                }

                record = outcome.record;
                MoveHistoryEntry last = record.moveHistory[record.moveHistory.size - 1];
                frames = frames.addAll([new Frame(last.fen, last.boardAfter, last.color, last.fromSquare,
                        last.toSquare, charToString(last.promotion), last.notation, last.isCheck, last.isCheckmate)]);
            } else {
                break;
            }
        }

        return frames;
    }

    // ----- SAN tokenizing -------------------------------------------------

    /**
     * Splits PGN movetext into SAN move tokens: headers (`[...]`) and comments (`{...}`) are
     * dropped, then whitespace-separated tokens that are move numbers (`12.`, `12...`) or game
     * results (`1-0`, `0-1`, `1/2-1/2`, `*`) are filtered out.
     */
    static String[] tokenize(String pgn) {
        StringBuffer cleaned = new StringBuffer();
        Int depth = 0;      // nested [ ... ]
        Boolean inBrace = False; // { ... }
        for (Char c : pgn) {
            if (c == '[') { depth++; continue; }
            if (c == ']') { if (depth > 0) { depth--; } continue; }
            if (c == '{') { inBrace = True; continue; }
            if (c == '}') { inBrace = False; continue; }
            if (depth > 0 || inBrace) { continue; }
            cleaned.add(c);
        }

        String[] tokens = new String[];
        StringBuffer word = new StringBuffer();
        for (Char c : cleaned.toString()) {
            if (c.isWhitespace()) {
                if (word.size > 0) {
                    tokens = tokens.addAll([word.toString()]);
                    word = new StringBuffer();
                }
            } else {
                word.add(c);
            }
        }
        if (word.size > 0) {
            tokens = tokens.addAll([word.toString()]);
        }

        String[] moves = new String[];
        for (String token : tokens) {
            if (isMoveNumber(token) || isResult(token)) {
                continue;
            }
            moves = moves.addAll([token]);
        }
        return moves;
    }

    private static Boolean isMoveNumber(String token) {
        Int i = 0;
        Boolean sawDigit = False;
        while (i < token.size && token[i].asciiDigit()) {
            sawDigit = True;
            i++;
        }
        if (!sawDigit || i >= token.size || token[i] != '.') {
            return False;
        }
        while (i < token.size && token[i] == '.') {
            i++;
        }
        return i == token.size;
    }

    private static String? charToString(Char? c) {
        if (Char value ?= c) {
            return value.toString();
        }
        return Null;
    }

    private static Boolean isResult(String token) =
            token == "1-0" || token == "0-1" || token == "1/2-1/2" || token == "*";

    // ----- SAN resolution -------------------------------------------------

    /** The characters a SAN token is allowed to carry; everything else (check/mate marks,
     *  annotation glyphs like "!?") is decoration and gets dropped. */
    private static Boolean isSanChar(Char c) =
            c.asciiLetter() || c.asciiDigit() || c == 'x' || c == '=' || c == '-';

    private static String sanitize(String token) {
        StringBuffer clean = new StringBuffer();
        for (Char c : token) {
            if (isSanChar(c)) {
                clean.add(c);
            }
        }
        return clean.toString();
    }

    private static Char caseFor(Char upperLetter, Color turn) =
            turn == White ? upperLetter : (upperLetter.toInt() + 32).toChar();

    /**
     * Resolves one SAN token (already free of move numbers) to the from/to squares and
     * promotion piece [ChessLogic.applyHumanMove] expects, by matching it against every legal
     * move of the position. Fails if the token is malformed or matches zero or more than one
     * legal move (an ambiguous or mistyped SAN).
     */
    static conditional (Int from, Int to, String? promotion) resolveSan(
            String rawToken, String board, Color turn, CastlingRights castlingRights, String? enPassantTarget) {
        String token = sanitize(rawToken);

        if (token == "O-O" || token == "0-0") {
            Int rank = turn == White ? 7 : 0;
            return (True, rank * 8 + 4, rank * 8 + 6, Null);
        }
        if (token == "O-O-O" || token == "0-0-0") {
            Int rank = turn == White ? 7 : 0;
            return (True, rank * 8 + 4, rank * 8 + 2, Null);
        }

        String? promotion = Null;
        if (Int eq := token.indexOf('=')) {
            if (eq + 1 < token.size) {
                promotion = token[eq + 1 ..< eq + 2].toLowercase();
            }
            token = token[0 ..< eq];
        }

        if (token.size < 2) {
            return False;
        }
        String dest = token[token.size - 2 ..< token.size];
        String prefix = token[0 ..< token.size - 2];

        Char pieceLetter = 'P';
        if (prefix.size > 0) {
            if (Int ignored := "NBRQK".indexOf(prefix[0])) {
                pieceLetter = prefix[0];
                prefix = prefix[1 ..< prefix.size];
            }
        }

        StringBuffer disambigBuf = new StringBuffer();
        for (Char c : prefix) {
            if (c != 'x') {
                disambigBuf.add(c);
            }
        }
        String disambig = disambigBuf.toString();

        Char expected = caseFor(pieceLetter, turn);

        MovePair[] legal = CheckDetection.getAllLegalMoves(board, turn, castlingRights, enPassantTarget);
        MovePair[] matches = new MovePair[];
        for (MovePair candidate : legal) {
            if (BoardUtils.toAlgebraic(candidate.toSquare) != dest) {
                continue;
            }
            if (board[candidate.fromSquare] != expected) {
                continue;
            }
            String fromAlg = BoardUtils.toAlgebraic(candidate.fromSquare);
            Boolean ok = True;
            for (Char d : disambig) {
                if (d.asciiDigit()) {
                    ok &= fromAlg[1] == d;
                } else {
                    ok &= fromAlg[0] == d;
                }
            }
            if (ok) {
                matches = matches.addAll([candidate]);
            }
        }

        if (matches.size != 1) {
            return False;
        }
        return (True, matches[0].fromSquare, matches[0].toSquare, promotion);
    }
}
