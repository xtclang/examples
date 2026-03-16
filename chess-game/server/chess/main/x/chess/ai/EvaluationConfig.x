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

    // King endgame table — king should centralize in the endgame
    Int[] kingTableEndgame = [
        -50,-40,-30,-20,-20,-30,-40,-50,
        -30,-20,-10,  0,  0,-10,-20,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 30, 40, 40, 30,-10,-30,
        -30,-10, 20, 30, 30, 20,-10,-30,
        -30,-30,  0,  0,  0,  0,-30,-30,
        -50,-30,-30,-30,-30,-30,-30,-50
    ];

    // Passed pawn bonus by rank (from Black's perspective: rank 0 = 8th rank = promotion)
    Int[] passedPawnBonusByRank = [0, 120, 80, 50, 30, 15, 10, 0];

    // ----- Endgame Bonuses -------------------------------------------------
    Int kingProximityBonus = 10;    // Bonus for king being close to opponent's king (mating)
    Int rookOn7thBonus = 20;        // Bonus for rook on 7th rank
    Int connectedRooksBonus = 15;   // Bonus for connected rooks

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
     * Uses endgame tables for king when isEndgame is True.
     */
    Int getPieceSquareValue(Char piece, Int square, Boolean isBlack, Boolean isEndgame = False) {
        Int index = isBlack ? square : (63 - square);

        switch (piece.lowercase) {
            case 'p': return pawnTable[index];
            case 'n': return knightTable[index];
            case 'b': return bishopTable[index];
            case 'r': return rookTable[index];
            case 'q': return queenTable[index];
            case 'k': return isEndgame ? kingTableEndgame[index] : kingTableMidgame[index];
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
