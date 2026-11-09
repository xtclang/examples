import db.models.CastlingRights;

/**
 * Parses a FEN string back into the board-state components [ChessGame.applyMove] needs -- the
 * inverse of [AIUtility.boardToFen]. Used to seed a replay from an arbitrary starting position
 * (a chess.com puzzle's FEN, for instance) rather than the standard starting position.
 */
@Abstract
class FenParser {
    /**
     * Parses a FEN string into a [GameRecord] ready to have moves applied to it via
     * [ChessLogic.applyHumanMove].
     *
     * The record's `moveHistory` starts empty, so if the FEN's own fullmove number is greater
     * than 1 (a mid-game position), the FEN embedded in each subsequently-replayed move's
     * [MoveHistoryEntry] will understate the fullmove number. That's harmless here: nothing
     * reads it back, since move resolution during replay works from from/to squares, not FEN
     * text.
     */
    static GameRecord fromFen(String fen) {
        String[] fields = fen.trim().split(' ');
        assert:arg fields.size >= 2 as $"Invalid FEN: {fen.quoted()}";

        String board = parseBoard(fields[0]);
        Color turn = fields[1] == "b" ? Black : White;
        CastlingRights castling = fields.size > 2 ? parseCastling(fields[2]) : new CastlingRights();
        String? enPassant = fields.size > 3 && fields[3] != "-" ? fields[3] : Null;
        Int halfMoveClock = 0;
        if (fields.size > 4) {
            if (Int parsed := Int.parse(fields[4])) {
                halfMoveClock = parsed;
            }
        }

        return new GameRecord(board, turn, GameStatus.Ongoing, Null, 0, 0, castling, enPassant, [], Null, halfMoveClock);
    }

    /**
     * Expands a FEN board field's `/`-separated, digit-run-compressed ranks into this
     * codebase's 64-character board string (rank 8 first, matching [AIUtility.boardToFen]).
     */
    private static String parseBoard(String boardField) {
        StringBuffer board = new StringBuffer();
        for (String rank : boardField.split('/')) {
            for (Char ch : rank) {
                if (ch.asciiDigit()) {
                    Int emptyCount = ch.toInt() - '0'.toInt();
                    for (Int i = 0; i < emptyCount; i++) {
                        board.add('.');
                    }
                } else {
                    board.add(ch);
                }
            }
        }
        assert:arg board.size == 64 as $"Invalid FEN board field: {boardField.quoted()}";
        return board.toString();
    }

    private static CastlingRights parseCastling(String field) {
        if (field == "-") {
            return new CastlingRights(False, False, False, False);
        }
        Boolean whiteKingside  = False;
        Boolean whiteQueenside = False;
        Boolean blackKingside  = False;
        Boolean blackQueenside = False;
        for (Char ch : field) {
            switch (ch) {
            case 'K': whiteKingside  = True; break;
            case 'Q': whiteQueenside = True; break;
            case 'k': blackKingside  = True; break;
            case 'q': blackQueenside = True; break;
            default: break;
            }
        }
        return new CastlingRights(whiteKingside, whiteQueenside, blackKingside, blackQueenside);
    }
}
