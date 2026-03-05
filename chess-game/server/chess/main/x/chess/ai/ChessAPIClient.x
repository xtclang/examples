/**
 * Chess API Client
 *
 * Integrates with the Stockfish Online public API for AI chess moves.
 * Instead of computing moves locally, this service:
 * 1. Converts the current board position to FEN notation
 * 2. Sends the FEN to the Stockfish Online API
 * 3. Parses the UCI best-move response
 * 4. Falls back to a random legal move if the API is unavailable
 *
 * API: https://stockfish.online/api/s/v2.php
 * Parameters: fen (FEN position string), depth (search depth 1-16)
 * Response: {"success": true, "data": "bestmove e2e4 ponder d7d5"}
 */
service ChessAPIClient {

    @Inject Client httpClient;

    static String API_BASE = "https://stockfish.online/api/s/v2.php";
    static Int    DEFAULT_DEPTH = 12;

    // ----- FEN Conversion -------------------------------------------------

    /**
     * Convert a GameRecord to FEN (Forsyth-Edwards Notation).
     *
     * FEN encodes the full game position in a single string with 6 fields:
     *  1. Piece placement (ranks 8→1, files a→h)
     *  2. Active color (w / b)
     *  3. Castling availability (KQkq or -)
     *  4. En passant target square (or -)
     *  5. Half-move clock (for 50-move rule)
     *  6. Full-move number
     */
    static String boardToFen(GameRecord record) {
        String fen = "";

        // 1. Piece placement — board[0..7] = rank 8, board[56..63] = rank 1
        for (Int rank = 0; rank < 8; rank++) {
            if (rank > 0) {
                fen += "/";
            }
            Int emptyCount = 0;
            for (Int file = 0; file < 8; file++) {
                Char piece = record.board[rank * 8 + file];
                if (piece == '.') {
                    emptyCount++;
                } else {
                    if (emptyCount > 0) {
                        fen += emptyCount.toString();
                        emptyCount = 0;
                    }
                    fen += piece.toString();
                }
            }
            if (emptyCount > 0) {
                fen += emptyCount.toString();
            }
        }

        // 2. Active color
        fen += record.turn == Color.White ? " w" : " b";

        // 3. Castling availability
        String castling = "";
        if (record.castlingRights.whiteKingside)  { castling += "K"; }
        if (record.castlingRights.whiteQueenside) { castling += "Q"; }
        if (record.castlingRights.blackKingside)  { castling += "k"; }
        if (record.castlingRights.blackQueenside) { castling += "q"; }
        fen += castling.size == 0 ? " -" : $" {castling}";

        // 4. En passant target
        fen += record.enPassantTarget != Null ? $" {record.enPassantTarget}" : " -";

        // 5. Half-move clock
        fen += $" {record.halfMoveClock}";

        // 6. Full-move number (starts at 1, increments after Black's move)
        Int fullmove = (record.moveHistory.size / 2) + 1;
        fen += $" {fullmove}";

        return fen;
    }

    // ----- URL Encoding ---------------------------------------------------

    /**
     * URL-encode a FEN string for safe use in query parameters.
     * Encodes spaces and slashes which are present in every FEN string.
     */
    static String urlEncodeFen(String fen) {
        String result = "";
        for (Char c : fen) {
            switch (c) {
                case ' ':  result += "+";    break;
                case '/':  result += "%2F";  break;
                default:   result += c.toString(); break;
            }
        }
        return result;
    }

    // ----- UCI Move Parsing -----------------------------------------------

    /**
     * Parse a UCI move string (e.g. "e2e4" or "e7e8q") into board indices.
     *
     * @return (fromIndex, toIndex, promotionChar?)  or (-1, -1, Null) on failure
     */
    static (Int, Int, String?) parseUCIMove(String move) {
        if (move.size < 4) {
            return (-1, -1, Null);
        }

        Int fromFile = move[0] - 'a';
        Int fromRank = 8 - (move[1] - '0');
        Int toFile   = move[2] - 'a';
        Int toRank   = 8 - (move[3] - '0');

        if (fromFile < 0 || fromFile > 7 || fromRank < 0 || fromRank > 7 ||
            toFile   < 0 || toFile   > 7 || toRank   < 0 || toRank   > 7) {
            return (-1, -1, Null);
        }

        Int from = fromRank * 8 + fromFile;
        Int to   = toRank   * 8 + toFile;

        // Optional promotion piece (5th character, e.g. 'q' in "e7e8q")
        String? promotion = move.size > 4 ? move[4].toString() : Null;

        return (from, to, promotion);
    }

    // ----- Response Parsing -----------------------------------------------

    /**
     * Extract the best-move token from the Stockfish API response body.
     *
     * The API returns JSON whose "data" field looks like:
     *   "bestmove e2e4 ponder d7d5"
     *
     * We scan the raw body for "bestmove " and grab the next non-space token.
     */
    static String extractBestMove(String responseBody) {
        String marker    = "bestmove ";
        Int    markerLen = 9;
        Int    bodyLen   = responseBody.size;

        for (Int i : 0 ..< bodyLen - markerLen + 1) {
            // Quick first-char check
            if (responseBody[i] != 'b') {
                continue;
            }
            // Verify full marker
            Boolean matched = True;
            for (Int j : 0 ..< markerLen) {
                if (responseBody[i + j] != marker[j]) {
                    matched = False;
                    break;
                }
            }
            if (matched) {
                // Grab the move token after the marker
                Int moveStart = i + markerLen;
                Int moveEnd   = moveStart;
                while (moveEnd < bodyLen
                        && responseBody[moveEnd] != ' '
                        && responseBody[moveEnd] != '"'
                        && responseBody[moveEnd] != '\\') {
                    moveEnd++;
                }
                if (moveEnd > moveStart) {
                    return responseBody[moveStart ..< moveEnd];
                }
            }
        }
        return "";
    }

    // ----- API Call -------------------------------------------------------

    /**
     * Query the Stockfish Online API for the best move in the given position.
     *
     * @return UCI move string (e.g. "e2e4") or "" on any failure
     */
    String queryStockfishAPI(String fen, Int depth = DEFAULT_DEPTH) {
        try {
            String encodedFen = urlEncodeFen(fen);
            String url        = $"{API_BASE}?fen={encodedFen}&depth={depth}";

            ResponseIn response = httpClient.get(url);
            if (String body := response.to(String)) {
                return extractBestMove(body);
            }
            return "";
        } catch (Exception e) {
            // API call failed – caller should use fallback
            return "";
        }
    }

    // ----- Best Move Selection --------------------------------------------

    /**
     * Find the best move for the current position.
     *
     * 1. Queries the Stockfish API
     * 2. Falls back to a random legal move if the API is unavailable
     *
     * @return (fromIndex, toIndex, promotion?) or (-1, -1, Null) if no moves
     */
    (Int, Int, String?) findBestMove(GameRecord record) {
        // Convert position to FEN and query the API
        String fen          = boardToFen(record);
        String bestMoveStr  = queryStockfishAPI(fen);

        if (bestMoveStr.size >= 4) {
            (Int from, Int to, String? promotion) = parseUCIMove(bestMoveStr);
            if (from >= 0 && to >= 0) {
                // Validate that the returned move is legal
                Char[] board = BoardUtils.cloneBoard(record.board);
                Char piece = board[from];
                if (piece != '.' && BoardUtils.colorOf(piece) == record.turn) {
                    return (from, to, promotion);
                }
            }
        }

        // Fallback: pick a random legal move
        return findRandomLegalMove(record);
    }

    // ----- Fallback -------------------------------------------------------

    /**
     * Select a random legal move as a fallback when the API is unavailable.
     * Uses a deterministic hash based on game state for reproducibility.
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

                // Verify move doesn't leave own king in check
                Char[] testBoard = BoardUtils.cloneBoard(new String(board));
                testBoard[to]   = piece;
                testBoard[from] = '.';
                if (CheckDetection.isInCheck(new String(testBoard), record.turn)) {
                    continue;
                }

                validFroms = validFroms + from;
                validTos   = validTos   + to;
            }
        }

        if (validFroms.empty) {
            return (-1, -1, Null);
        }

        // Deterministic pseudo-random selection based on game state
        Int moveCount = record.moveHistory.size;
        Int hash = moveCount ^ (validFroms.size * 2654435761);
        hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
        hash = (hash >> 16) ^ hash;
        Int index = hash.abs() % validFroms.size;

        return (validFroms[index], validTos[index], Null);
    }
}
