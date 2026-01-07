@oodb.Database
module chessDB.examples.org {
    package auth import webauth.xtclang.org;
    package oodb import oodb.xtclang.org;

    /** Side to move. */
    enum Color { White, Black }

    /** Game lifecycle marker. */
    enum GameStatus { Ongoing, Checkmate, Stalemate }

    /**
     * Persisted snapshot of a chess game.
     * - board: 64-character string, row-major from a8 to h1
     * - turn: side whose move it is
     * - status: coarse result tracking (no detailed check validation yet)
     * - lastMove: algebraic-like source->target (e.g. "e2e4")
     */
    const GameRecord(String board,
                     Color  turn,
                     GameStatus status = Ongoing,
                     String? lastMove = Null,
                     Int playerScore = 0,
                     Int opponentScore = 0) {}

    interface ChessSchema
            extends oodb.RootSchema {
        /** Stored games keyed by a simple integer id. */
        @RO oodb.DBMap<Int, GameRecord> games;

        /** Web authentication schema */
        @RO auth.AuthSchema authSchema;
    }
}
