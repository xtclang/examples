module chessLogic.examples.org {
    package db import chessDB.examples.org;

    import db.ChessSchema;
    import db.GameRecord;
    import db.GameStatus;
    import db.Color;
~
service ChessLogic {
    static Int BOARD_SIZE = 8;
    static Int FILE_STEP = 1;
    static Int RANK_STEP = 8;
    static Char FILE_MIN = 'a';
    static Char FILE_MAX = 'h';
    static Char RANK_MIN = '1';
    static Char RANK_MAX = '8';
    static Int SQUARE_STRING_LENGTH = 2;
    static Int INVALID_SQUARE = -1;
    static Int MAX_RANK_INDEX = 7;
    static Int WHITE_PAWN_START_RANK = 6;
    static Int BLACK_PAWN_START_RANK = 1;
    static Int WHITE_PROMOTION_RANK = 0;
    static Int BLACK_PROMOTION_RANK = 7;
    static Int CENTER_FILE = 3;
    static Int CENTER_RANK = 3;
    static Int CENTER_BONUS_BASE = 5;
    static Int PROMOTION_BONUS = 8;
    static Int CHECKMATE_SCORE = 1000;
    static Int MIN_SCORE = -10000;

    static MoveOutcome applyHumanMove(GameRecord record, String fromSquare, String toSquare, String? promotion = Null) {
        if (record.status != GameStatus.Ongoing) {
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

        Color mover = colorOf(piece);
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

        GameRecord updated = applyMove(record, cloneBoard(record.board), from, to, promotion);
        return new MoveOutcome(True, updated, updated.lastMove ?: "Move applied");
    }

    static AutoResponse autoMove(GameRecord record) {
        if (record.status != GameStatus.Ongoing || record.turn != Color.Black) {
            return new AutoResponse(False, record, "Ready for a move");
        }

        Char[] board = cloneBoard(record.board);
        Int    squares = board.size;
        Int    bestScore = MIN_SCORE;
        AutoResponse? best = Null;

        for (Int from : 0 ..< squares) {
            Char piece = board[from];
            if (piece == '.' || colorOf(piece) != Color.Black) {
                continue;
            }

            for (Int to = 0; to < squares; ++to) {
                if (from == to) {
                    continue;
                }

                Char target = board[to];
                if (target != '.' && colorOf(target) == Color.Black) {
                    continue;
                }

                if (!isLegal(piece, from, to, board)) {
                    continue;
                }

                Char[] boardCopy      = cloneBoard(record.board);
                GameRecord updated = applyMove(record, boardCopy, from, to, Null);
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

        GameRecord stalemate = new GameRecord(record.board,
                                                    record.turn,
                                                    GameStatus.Stalemate,
                                                    record.lastMove,
                                                    record.playerScore,
                                                    record.opponentScore);
        return new AutoResponse(False, stalemate, "Opponent has no legal moves");
    }

    static GameRecord defaultGame() {
        return new GameRecord(INITIAL_BOARD, Color.White);
    }

    static GameRecord resetGame() {
        return new GameRecord(INITIAL_BOARD,
                                 Color.White,
                                 GameStatus.Ongoing,
                                 Null,
                                 0,
                                 0);
    }

    static String[] boardRows(String board) {
        String[] rows = new String[](BOARD_SIZE);
        for (Int i : 0 ..< BOARD_SIZE) {
            rows[i] = board[i * BOARD_SIZE ..< (i + 1) * BOARD_SIZE];
        }
        return rows;
    }

    // ----- internal helpers -------------------------------------------------

    static GameRecord applyMove(GameRecord record, Char[] board, Int from, Int to, String? promotion) {
        Char piece = board[from];
        Color mover = colorOf(piece);
        Char target = board[to];
        Boolean captured = target != '.';

        Char moved = promoteIfNeeded(piece, to, promotion);
        board[to]   = moved;
        board[from] = '.';

        String newBoard = new String(board);
        Color next   = mover == Color.White ? Color.Black : Color.White;
        GameStatus status = detectStatus(board);
        String moveTag = formatSquare(from) + formatSquare(to);

        Int playerScore   = record.playerScore;
        Int opponentScore = record.opponentScore;
        if (captured) {
            if (mover == Color.White) {
                ++playerScore;
            } else {
                ++opponentScore;
            }
        }

        return new GameRecord(newBoard,
                                 next,
                                 status,
                                 moveTag,
                                 playerScore,
                                 opponentScore);
    }

    static GameStatus detectStatus(Char[] board) {
        Boolean whiteHasPieces = False;
        Boolean blackHasPieces = False;
        for (Char c : board) {
            if (c == '.') {
                continue;
            }
            if (colorOf(c) == Color.White) {
                whiteHasPieces = True;
            } else {
                blackHasPieces = True;
            }
        }

        if (!whiteHasPieces || !blackHasPieces) {
            return GameStatus.Checkmate;
        }
        return GameStatus.Ongoing;
    }

    static Boolean isLegal(Char piece, Int from, Int to, Char[] board) {
        Color mover = colorOf(piece);
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
            Int dir      = mover == Color.White ? -1 : +1;
            Int startRow = mover == Color.White ? WHITE_PAWN_START_RANK : BLACK_PAWN_START_RANK;
            Char target  = board[to];
            if (df == 0 && dr == dir && target == '.') {
                return True;
            }
            if (df == 0 && dr == dir * 2 && fromRank == startRow && target == '.') {
                Int mid = from + dir * RANK_STEP;
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
                Int step = (dr > 0 ? RANK_STEP : -RANK_STEP) + (df > 0 ? FILE_STEP : -FILE_STEP);
                return clearPath(board, from, to, step);
            }
            return False;

        case 'R':
            if (df == 0 && adr != 0) {
                Int step = dr > 0 ? RANK_STEP : -RANK_STEP;
                return clearPath(board, from, to, step);
            }
            if (dr == 0 && adf != 0) {
                Int step = df > 0 ? FILE_STEP : -FILE_STEP;
                return clearPath(board, from, to, step);
            }
            return False;

        case 'Q':
            if (df == 0 || dr == 0) {
                Int step = df == 0 ? (dr > 0 ? RANK_STEP : -RANK_STEP) : (df > 0 ? FILE_STEP : -FILE_STEP);
                return clearPath(board, from, to, step);
            }
            if (adf == adr && adf != 0) {
                Int step = (dr > 0 ? RANK_STEP : -RANK_STEP) + (df > 0 ? FILE_STEP : -FILE_STEP);
                return clearPath(board, from, to, step);
            }
            return False;

        case 'K':
            return adf <= 1 && adr <= 1 && (adf + adr > 0);

        default:
            return False;
        }
    }

    static Boolean clearPath(Char[] board, Int from, Int to, Int step) {
        for (Int idx = from + step; idx != to; idx += step) {
            if (board[idx] != '.') {
                return False;
            }
        }
        return True;
    }

    static Int evaluateMove(Char piece, Char target, Int to, GameStatus status) {
        Int score = pieceValue(target);
        score += positionBonus(to);
        if (status == GameStatus.Checkmate) {
            score += CHECKMATE_SCORE;
        }
        if (upper(piece) == 'P' && (rankIndex(to) == WHITE_PROMOTION_RANK || rankIndex(to) == BLACK_PROMOTION_RANK)) {
            score += PROMOTION_BONUS;
        }
        return score;
    }

    enum PieceType { Pawn, Knight, Bishop, Rook, Queen, King }

    static Map<Char, Int> PIECE_VALUES = Map:[
        'P'=1, 'N'=3, 'B'=3, 'R'=5, 'Q'=9, 'K'=100,
        'p'=1, 'n'=3, 'b'=3, 'r'=5, 'q'=9, 'k'=100
    ];
    
    static Int pieceValue(Char piece) {
        return PIECE_VALUES.getOrDefault(piece, 0);
    }

    static Int positionBonus(Int index) {
        Int file = fileIndex(index);
        Int rank = rankIndex(index);
        Int centerDistance = (file - CENTER_FILE).abs() + (rank - CENTER_RANK).abs();
        return CENTER_BONUS_BASE - centerDistance;
    }

    static Int parseSquare(String square) {
        if (square.size != SQUARE_STRING_LENGTH) {
            return INVALID_SQUARE;
        }
        Char file = square[0];
        Char rank = square[1];
        if (file < FILE_MIN || file > FILE_MAX || rank < RANK_MIN || rank > RANK_MAX) {
            return INVALID_SQUARE;
        }
        Int f = file - FILE_MIN;
        Int r = rank - RANK_MIN;
        return (MAX_RANK_INDEX - r) * 8 + f;
    }

    static String formatSquare(Int index) {
        Int r = MAX_RANK_INDEX - rankIndex(index);
        Int f = fileIndex(index);
        Char file = FILE_MIN + f;
        Char rank = RANK_MIN + r;
        return $"{file}{rank}";
    }

    static Int fileIndex(Int index) = index % BOARD_SIZE;
    static Int rankIndex(Int index) = index / BOARD_SIZE;

    static Color colorOf(Char piece) {
        return piece >= FILE_MIN && piece <= 'z' ? Color.Black : Color.White;
    }

    static Char upper(Char piece) {
        if (piece >= FILE_MIN && piece <= 'z') {
            Int offset = piece - FILE_MIN;
            return 'A' + offset;
        }
        return piece;
    }

    static Char promoteIfNeeded(Char piece, Int to, String? promotion) {
        if (upper(piece) != 'P') {
            return piece;
        }
        Int rank = rankIndex(to);
        Boolean isWhite = colorOf(piece) == Color.White;
        if ((isWhite && rank == WHITE_PROMOTION_RANK) || (!isWhite && rank == BLACK_PROMOTION_RANK)) {
            Char promo = 'Q';
            if (promotion != Null && promotion.size == 1) {
                promo = upper(promotion[0]);
            }
            return isWhite ? promo : (FILE_MIN + (promo - 'A'));
        }
        return piece;
    }

    static Char[] cloneBoard(String board) {
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

    const MoveOutcome(Boolean ok, GameRecord record, String message) {}

    const AutoResponse(Boolean moved, GameRecord record, String message) {}
}
