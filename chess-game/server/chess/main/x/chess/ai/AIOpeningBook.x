/**
 * Opening book move selection.
 */
service AIOpeningBook {
    static String[][] OPENING_RESPONSES = [
        ["e7e5", "c7c5", "e7e6", "c7c6", "d7d5", "g8f6"],
        ["d7d5", "g8f6", "e7e6", "c7c5", "f7f5"],
        ["g8f6", "d7d5", "e7e6", "c7c6", "e7e5", "c7c5", "g7g6"]
    ];

    static (Int, Int) getOpeningMove(GameRecord record) {
        if (record.moveHistory.size >= 12) {
            return (-1, -1);
        }

        Char[] board = BoardUtils.cloneBoard(record.board);
        Int moveCount = record.moveHistory.size;

        Int[] validFroms = new Int[];
        Int[] validTos = new Int[];

        for (String[] responses : OPENING_RESPONSES) {
            for (String move : responses) {
                if (move.size != 4) {
                    continue;
                }
                Int fromFile = move[0] - 'a';
                Int fromRank = 8 - (move[1] - '0');
                Int toFile   = move[2] - 'a';
                Int toRank   = 8 - (move[3] - '0');
                Int from = fromRank * 8 + fromFile;
                Int to   = toRank   * 8 + toFile;

                if (from < 0 || from >= 64 || to < 0 || to >= 64) {
                    continue;
                }

                Char piece = board[from];
                if (piece == '.' || BoardUtils.colorOf(piece) != Black) {
                    continue;
                }
                Char target = board[to];
                if (target != '.' && BoardUtils.colorOf(target) == Black) {
                    continue;
                }
                if (!PieceValidator.isLegal(piece, from, to, board,
                        record.castlingRights, record.enPassantTarget)) {
                    continue;
                }

                Char[] testBoard = BoardUtils.cloneBoard(board);
                testBoard[to] = piece;
                testBoard[from] = '.';
                if (CheckDetection.isInCheck(testBoard.freeze(), Black)) {
                    continue;
                }

                validFroms = validFroms + from;
                validTos = validTos + to;
            }
        }

        if (validFroms.empty) {
            return (-1, -1);
        }

        Int index = AIUtility.hashRandom(moveCount * 1009, validFroms.size) % validFroms.size;
        return (validFroms[index], validTos[index]);
    }
}
