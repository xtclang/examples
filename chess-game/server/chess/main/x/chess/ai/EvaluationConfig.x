/**
 * Position Evaluation Config
 * Centralizes all scoring constants and piece-square tables.
 * Allows easy tuning and reduces hard-coded values throughout the codebase.
 */
const EvaluationConfig {
    // ----- Material Values (centipawns) -------------------------------------------------
    Int pawnValue = 100;
    Int knightValue = 320;
    Int bishopValue = 330;
    Int rookValue = 500;
    Int queenValue = 900;
    Int kingValue = 20000;

    // ----- Positional Bonuses -------------------------------------------------
    Int checkBonus = 50;
    Int castlingBonus = 60;
    Int developmentBonus = 30;
    Int centerControlBonus = 25;
    Int mobilityBonus = 5;

    // ----- Pawn Structure -------------------------------------------------
    Int doubledPawnPenalty = -20;
    Int isolatedPawnPenalty = -25;
    Int passedPawnBonus = 50;

    // ----- Piece-Square Tables -------------------------------------------------
    Int[] pawnTable = [
         0,  0,  0,  0,  0,  0,  0,  0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
         5,  5, 10, 25, 25, 10,  5,  5,
         0,  0,  0, 20, 20,  0,  0,  0,
         5, -5,-10,  0,  0,-10, -5,  5,
         5, 10, 10,-20,-20, 10, 10,  5,
         0,  0,  0,  0,  0,  0,  0,  0
    ];

    Int[] knightTable = [
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -30,  0, 10, 15, 15, 10,  0,-30,
        -30,  5, 15, 20, 20, 15,  5,-30,
        -30,  0, 15, 20, 20, 15,  0,-30,
        -30,  5, 10, 15, 15, 10,  5,-30,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50
    ];

    Int[] bishopTable = [
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5, 10, 10,  5,  0,-10,
        -10,  5,  5, 10, 10,  5,  5,-10,
        -10,  0, 10, 10, 10, 10,  0,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -20,-10,-10,-10,-10,-10,-10,-20
    ];

    Int[] rookTable = [
         0,  0,  0,  0,  0,  0,  0,  0,
         5, 10, 10, 10, 10, 10, 10,  5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
         0,  0,  0,  5,  5,  0,  0,  0
    ];

    Int[] queenTable = [
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -10,  0,  5,  5,  5,  5,  0,-10,
         -5,  0,  5,  5,  5,  5,  0, -5,
          0,  0,  5,  5,  5,  5,  0, -5,
        -10,  5,  5,  5,  5,  5,  0,-10,
        -10,  0,  5,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20
    ];

    Int[] kingTableMidgame = [
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -10,-20,-20,-20,-20,-20,-20,-10,
         20, 20,  0,  0,  0,  0, 20, 20,
         20, 30, 10,  0,  0, 10, 30, 20
    ];

    /**
     * Get material value for a piece.
     */
    Int getPieceValue(Char piece) {

        switch (piece.lowercase) {
            case 'p': return pawnValue;
            case 'n': return knightValue;
            case 'b': return bishopValue;
            case 'r': return rookValue;
            case 'q': return queenValue;
            case 'k': return kingValue;
            default: return 0;
        }
    }

    /**
     * Get piece-square table value.
     */
    Int getPieceSquareValue(Char piece, Int square, Boolean isBlack) {
        Int index = isBlack ? square : (63 - square);

        switch (piece.lowercase) {
            case 'p': return pawnTable[index];
            case 'n': return knightTable[index];
            case 'b': return bishopTable[index];
            case 'r': return rookTable[index];
            case 'q': return queenTable[index];
            case 'k': return kingTableMidgame[index];
            default: return 0;
        }
    }

    /**
     * Create a custom configuration with modified values.
     */
    static EvaluationConfig custom(
        Int? pawnValue = Null,
        Int? knightValue = Null,
        Int? bishopValue = Null,
        Int? rookValue = Null,
        Int? queenValue = Null
    ) {
        EvaluationConfig config = new EvaluationConfig();
        // Allow overriding specific values
        // This would require mutable config or builder pattern
        return config;
    }
}
