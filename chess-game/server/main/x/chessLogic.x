module chessLogic.examples.org {
    package db import chessDB.examples.org;

    const MoveOutcome(Boolean ok, db.GameRecord record, String message);

    const AutoResponse(Boolean moved, db.GameRecord record, String message);

    MoveOutcome tryApplyMove(db.GameRecord record, String fromSquare, String toSquare, String? promotion) {
        if (record.status != db.GameStatus.Ongoing) {
            return new MoveOutcome(False, record, "Game already finished");
        }

        Int from = parseSquare(fromSquare);
        Int to   = parseSquare(toSquare);
        if (from < 0 || to < 0) {
            return new MoveOutcome(False, record, "Invalid square format");
        }

        Char[] board = cloneBoard(record.board);
        Char   piece = board[from];
        if (piece == '.') {
            return new MoveOutcome(False, record, "No piece on source square");
        }

        db.Color mover = colorOf(piece);
        if (mover != record.turn) {
            return new MoveOutcome(False, record, "Not your turn");
        }

        Char target = board[to];
        if (target != '.' && colorOf(target) == mover) {
            return new MoveOutcome(False, record, "Cannot capture your own piece");
        }

        if (!isLegal(piece, from, to, board)) {
            return new MoveOutcome(False, record, "Illegal move for that piece");
        }

        db.GameRecord updated = applyMove(record, cloneBoard(record.board), from, to, promotion);
        return new MoveOutcome(True, updated, updated.lastMove ?: "Move applied");
    }

    AutoResponse autoMove(db.GameRecord record) {
        if (record.status != db.GameStatus.Ongoing || record.turn != db.Color.Black) {
            return new AutoResponse(False, record, "Ready for a move");
        }

        Char[] board = cloneBoard(record.board);
        Int    squares = board.size;
        Int    bestScore = -1_000_000;
        AutoResponse? best = Null;

        for (Int from = 0; from < squares; ++from) {
            Char piece = board[from];
            if (piece == '.' || colorOf(piece) != db.Color.Black) {
                continue;
            }

            for (Int to = 0; to < squares; ++to) {
                if (from == to) {
                    continue;
                }

                Char target = board[to];
                if (target != '.' && colorOf(target) == db.Color.Black) {
                    continue;
                }

                if (!isLegal(piece, from, to, board)) {
                    continue;
                }

                Char[] boardCopy      = cloneBoard(record.board);
                db.GameRecord updated = applyMove(record, boardCopy, from, to, Null);
                Int score             = evaluateMove(piece, target, to, updated.status);
                String message        = $"Opponent moves {formatSquare(from)}{formatSquare(to)}";

                if (score > bestScore) {
                    bestScore = score;
                    best      = new AutoResponse(True, updated, message);
                }
            }
        }

        if (best != Null) {
            return best;
        }

        db.GameRecord stalemate = new db.GameRecord(record.board,
                                                    record.turn,
                                                    db.GameStatus.Stalemate,
                                                    record.lastMove,
                                                    record.playerScore,
                                                    record.opponentScore);
        return new AutoResponse(False, stalemate, "Opponent has no legal moves");
    }

    db.GameRecord defaultGame() {
        return new db.GameRecord(INITIAL_BOARD, db.Color.White);
    }

    db.GameRecord resetGame() {
        return new db.GameRecord(INITIAL_BOARD,
                                 db.Color.White,
                                 db.GameStatus.Ongoing,
                                 Null,
                                 0,
                                 0);
    }

    String[] boardRows(String board) {
        String[] rows = new Array<String>(8);
        for (Int i = 0; i < 8; ++i) {
            rows[i] = board[i * 8 ..< (i + 1) * 8];
        }
        return rows;
    }

    // ----- internal helpers -------------------------------------------------

    db.GameRecord applyMove(db.GameRecord record, Char[] board, Int from, Int to, String? promotion) {
        Char piece = board[from];
        db.Color mover = colorOf(piece);
        Char target = board[to];
        Boolean captured = target != '.';

        Char moved = promoteIfNeeded(piece, to, promotion);
        board[to]   = moved;
        board[from] = '.';

        String newBoard = new String(board);
        db.Color next   = mover == db.Color.White ? db.Color.Black : db.Color.White;
        db.GameStatus status = detectStatus(board);
        String moveTag = formatSquare(from) + formatSquare(to);

        Int playerScore   = record.playerScore;
        Int opponentScore = record.opponentScore;
        if (captured) {
            if (mover == db.Color.White) {
                ++playerScore;
            } else {
                ++opponentScore;
            }
        }

        return new db.GameRecord(newBoard,
                                 next,
                                 status,
                                 moveTag,
                                 playerScore,
                                 opponentScore);
    }

    db.GameStatus detectStatus(Char[] board) {
        Boolean whiteHasPieces = False;
        Boolean blackHasPieces = False;
        for (Char c : board) {
            if (c == '.') {
                continue;
            }
            if (colorOf(c) == db.Color.White) {
                whiteHasPieces = True;
            } else {
                blackHasPieces = True;
            }
        }

        if (!whiteHasPieces || !blackHasPieces) {
            return db.GameStatus.Checkmate;
        }
        return db.GameStatus.Ongoing;
    }

    Boolean isLegal(Char piece, Int from, Int to, Char[] board) {
        db.Color mover = colorOf(piece);
        Int fromFile   = fileIndex(from);
        Int fromRank   = rankIndex(from);
        Int toFile     = fileIndex(to);
        Int toRank     = rankIndex(to);
        Int df         = toFile - fromFile;
        Int dr         = toRank - fromRank;
        Int adf        = df >= 0 ? df : -df;
        Int adr        = dr >= 0 ? dr : -dr;

        Char type = upper(piece);
        switch (type) {
        case 'P':
            Int dir      = mover == db.Color.White ? -1 : +1;
            Int startRow = mover == db.Color.White ? 6 : 1;
            Char target  = board[to];
            if (df == 0 && dr == dir && target == '.') {
                return True;
            }
            if (df == 0 && dr == dir * 2 && fromRank == startRow && target == '.') {
                Int mid = from + dir * 8;
                return board[mid] == '.';
            }
            if (adf == 1 && dr == dir && target != '.' && colorOf(target) != mover) {
                return True;
            }
            return False;

        case 'N':
            return (adf == 1 && adr == 2) || (adf == 2 && adr == 1);

        case 'B':
            if (adf == adr && adf != 0) {
                Int step = (dr > 0 ? 8 : -8) + (df > 0 ? 1 : -1);
                return clearPath(board, from, to, step);
            }
            return False;

        case 'R':
            if (df == 0 && adr != 0) {
                Int step = dr > 0 ? 8 : -8;
                return clearPath(board, from, to, step);
            }
            if (dr == 0 && adf != 0) {
                Int step = df > 0 ? 1 : -1;
                return clearPath(board, from, to, step);
            }
            return False;

        case 'Q':
            if (df == 0 || dr == 0) {
                Int step = df == 0 ? (dr > 0 ? 8 : -8) : (df > 0 ? 1 : -1);
                return clearPath(board, from, to, step);
            }
            if (adf == adr && adf != 0) {
                Int step = (dr > 0 ? 8 : -8) + (df > 0 ? 1 : -1);
                return clearPath(board, from, to, step);
            }
            return False;

        case 'K':
            return adf <= 1 && adr <= 1 && (adf + adr > 0);

        default:
            return False;
        }
    }

    Boolean clearPath(Char[] board, Int from, Int to, Int step) {
        for (Int idx = from + step; idx != to; idx += step) {
            if (board[idx] != '.') {
                return False;
            }
        }
        return True;
    }

    Int evaluateMove(Char piece, Char target, Int to, db.GameStatus status) {
        Int score = pieceValue(target);
        score += positionBonus(to);
        if (status == db.GameStatus.Checkmate) {
            score += 1000;
        }
        if (upper(piece) == 'P' && (to / 8 == 0 || to / 8 == 7)) {
            score += 5;
        }
        return score;
    }

    Int pieceValue(Char piece) {
        switch (upper(piece)) {
        case 'P':
            return 1;
        case 'N':
        case 'B':
            return 3;
        case 'R':
            return 5;
        case 'Q':
            return 9;
        case 'K':
            return 100;
        default:
            return 0;
        }
    }

    Int positionBonus(Int index) {
        Int file = fileIndex(index);
        Int rank = rankIndex(index);
        Int centerDistance = (file - 3).abs() + (rank - 3).abs();
        return 4 - centerDistance;
    }

    Int parseSquare(String square) {
        if (square.size != 2) {
            return -1;
        }
        Char file = square[0];
        Char rank = square[1];
        if (file < 'a' || file > 'h' || rank < '1' || rank > '8') {
            return -1;
        }
        Int f = file - 'a';
        Int r = rank - '1';
        return (7 - r) * 8 + f;
    }

    String formatSquare(Int index) {
        Int r = 7 - rankIndex(index);
        Int f = fileIndex(index);
        Char file = 'a' + f;
        Char rank = '1' + r;
        return $"{file}{rank}";
    }

    Int fileIndex(Int index) = index % 8;
    Int rankIndex(Int index) = index / 8;

    db.Color colorOf(Char piece) {
        return piece >= 'a' && piece <= 'z' ? db.Color.Black : db.Color.White;
    }

    Char upper(Char piece) {
        if (piece >= 'a' && piece <= 'z') {
            Int offset = piece - 'a';
            return 'A' + offset;
        }
        return piece;
    }

    Char promoteIfNeeded(Char piece, Int to, String? promotion) {
        if (upper(piece) != 'P') {
            return piece;
        }
        Int rank = rankIndex(to);
        Boolean isWhite = colorOf(piece) == db.Color.White;
        if ((isWhite && rank == 0) || (!isWhite && rank == 7)) {
            Char promo = 'Q';
            if (promotion != Null && promotion.size == 1) {
                promo = upper(promotion[0]);
            }
            return isWhite ? promo : ('a' + (promo - 'A'));
        }
        return piece;
    }

    Char[] cloneBoard(String board) {
        Int size    = board.size;
        Char[] copy = new Char[size];
        for (Int i = 0; i < size; ++i) {
            copy[i] = board[i];
        }
        return copy;
    }

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
