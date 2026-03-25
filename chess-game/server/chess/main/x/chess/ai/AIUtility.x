/**
 * Generic AI utility helpers.
 */
service AIUtility {
    /**
     * Deterministic hash-based pseudo-random helper.
     */
    static Int hashRandom(Int seed, Int counter) {
        Int hash = seed ^ (counter * 2654435761);
        hash = ((hash >> 16) ^ hash) * 73244475;
        hash = ((hash >> 16) ^ hash) * 73244475;
        hash = (hash >> 16) ^ hash;
        return hash.abs();
    }

    /**
     * Picks any legal move for the side to move, used as fallback behavior.
     */
    static (Int, Int, String?) findRandomLegalMove(GameRecord record) {
        Char[] board = BoardUtils.cloneBoard(record.board);
        Int[] validFroms = new Int[];
        Int[] validTos   = new Int[];

        for (Int from : 0 ..< 64) {
            Char piece = board[from];
            if (piece == '.' || BoardUtils.colorOf(piece) != record.turn) {
                continue;
            }
            for (Int to : 0 ..< 64) {
                if (from == to) {
                    continue;
                }
                Char target = board[to];
                if (target != '.' && BoardUtils.colorOf(target) == record.turn) {
                    continue;
                }
                if (!PieceValidator.isLegal(piece, from, to, board,
                        record.castlingRights, record.enPassantTarget)) {
                    continue;
                }

                Char[] testBoard = BoardUtils.cloneBoard(board);
                testBoard[to]   = piece;
                testBoard[from] = '.';
                if (CheckDetection.isInCheck(testBoard.freeze(), record.turn)) {
                    continue;
                }

                validFroms = validFroms + from;
                validTos   = validTos   + to;
            }
        }

        if (validFroms.empty) {
            return (-1, -1, Null);
        }

        Int index = hashRandom(record.moveHistory.size, validFroms.size) % validFroms.size;
        return (validFroms[index], validTos[index], Null);
    }

    /**
     * Converts current game state to a FEN-like notation string.
     */
    static String boardToFen(GameRecord record) {
        StringBuffer fen = new StringBuffer();

        for (Int rank = 0; rank < 8; rank++) {
            if (rank > 0) {
                fen.addAll("/");
            }
            Int emptyCount = 0;
            for (Int file = 0; file < 8; file++) {
                Char piece = record.board[rank * 8 + file];
                if (piece == '.') {
                    emptyCount++;
                } else {
                    if (emptyCount > 0) {
                        fen.addAll(emptyCount.toString());
                        emptyCount = 0;
                    }
                    fen.addAll(piece.toString());
                }
            }
            if (emptyCount > 0) {
                fen.addAll(emptyCount.toString());
            }
        }

        fen.addAll(record.turn == Color.White ? " w" : " b");

        StringBuffer castling = new StringBuffer();
        if (record.castlingRights.whiteKingside)  { castling.addAll("K"); }
        if (record.castlingRights.whiteQueenside) { castling.addAll("Q"); }
        if (record.castlingRights.blackKingside)  { castling.addAll("k"); }
        if (record.castlingRights.blackQueenside) { castling.addAll("q"); }
        if (castling.size == 0) {
            fen.addAll(" -");
        } else {
            fen.addAll(" ");
            fen.addAll(castling.toString());
        }

        if (record.enPassantTarget != Null) {
            fen.addAll(" ");
            fen.addAll(record.enPassantTarget.toString());
        } else {
            fen.addAll(" -");
        }
        fen.addAll(" ");
        fen.addAll(record.halfMoveClock.toString());

        Int fullmove = (record.moveHistory.size / 2) + 1;
        fen.addAll(" ");
        fen.addAll(fullmove.toString());

        return fen.toString();
    }
}
