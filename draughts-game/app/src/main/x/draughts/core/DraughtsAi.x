import db.models.Color;
import core.DraughtsRules.Move;

/**
 * DraughtsAi - the computer opponent.
 *
 * It uses minimax search with alpha-beta pruning, the classic technique for game-playing
 * programs (and the one the Compator course demo uses):
 *
 *   1. List every legal move.
 *   2. For each, imagine the opponent's best reply, then our best reply to that, and so on, to a
 *      fixed number of moves ahead (the "depth").
 *   3. Score the position at the end of each imagined line with an evaluation function (roughly:
 *      who has more pieces, and better placed ones).
 *   4. Assume both sides always pick their best option, and choose the move that leads to the
 *      best guaranteed score.
 *
 * Alpha-beta pruning skips lines that cannot change the decision, so the search can look further
 * ahead in the same time.
 *
 * Difficulty is how far ahead the computer looks, and how often it plays a deliberately random
 * move, like a distracted human.
 *
 * One difference from a search in a browser: this runs inside a web request on the server, so a
 * deep search must not be allowed to take unbounded time. The search is iterative: it looks one
 * move ahead, then two, then three, and so on up to the level's depth, and plays the best move of
 * the deepest search that finished inside the level's time budget. On a fast machine every level
 * reaches its full depth; on a slow one the computer simply plays a little shallower.
 */
service DraughtsAi {
    /**
     * How hard a level plays.
     *
     * @param depth          how many moves ahead the search looks
     * @param randomPercent  the chance (0-100) that a move is chosen at random instead
     * @param label          the level's display name
     * @param budgetMs       the most time, in milliseconds, to spend deepening the search
     */
    static const Level(String name, String label, Int depth, Int randomPercent, Int budgetMs);

    static Level EASY   = new Level("easy",   "Low",    2, 35, 1500);
    static Level MEDIUM = new Level("medium", "Medium", 4, 10, 2500);
    static Level HARD   = new Level("hard",   "High",   7,  0, 4000);

    /**
     * What a search returns when its time ran out; the result is thrown away.
     */
    static Int ABORT = -2_000_000_000;

    /**
     * A score bigger than any position's value: a won game.
     */
    static Int WIN_SCORE = 100000;

    /**
     * Bigger than any score, standing in for infinity.
     */
    static Int INFINITE = 1_000_000_000;

    /**
     * The settings for a level name; anything unrecognized plays at medium strength.
     */
    static Level levelFor(String name) {
        return switch (name) {
            case "easy": EASY;
            case "hard": HARD;
            default: MEDIUM;
        };
    }

    /**
     * Score a position from the point of view of `player`: positive is good for `player`,
     * negative is good for the opponent.
     */
    static Int evaluate(String board, Color player) = evaluate(DraughtsRules.BoardCopy.of(board), player);

    static Int evaluate(Char[] board, Color player) {
        Boolean forBlack = player == Black;
        Int     score    = 0;
        for (Int i : 0 ..< 64) {
            Char piece = board[i];
            if (piece == '.') {
                continue;
            }
            Int row = i / 8;
            Int col = i % 8;
            Int value;
            Boolean black = piece == 'b' || piece == 'B';
            if (piece == 'B' || piece == 'W') {
                value = 175;
            } else {
                // Men are worth more the closer they are to being crowned.
                Int advance = black ? 7 - row : row;
                value = 100 + advance * 3;
                // Men on the back row guard against the opponent crowning.
                if ((black && row == 7) || (!black && row == 0)) {
                    value += 6;
                }
            }
            // A small bonus for the centre of the board, where pieces are flexible.
            if (row >= 2 && row <= 5 && col >= 2 && col <= 5) {
                value += 4;
            }
            score += black == forBlack ? value : -value;
        }
        return score;
    }

    /**
     * Minimax with alpha-beta pruning.
     *
     * @param board       the position to look at
     * @param turn        who is to move in it
     * @param depth       how many more moves to look ahead
     * @param alpha       the best score already guaranteed to the computer
     * @param beta        the best score already guaranteed to the opponent
     * @param maximising  True when it is the computer's turn in this imagined line
     * @param computer    the side the computer plays
     * @param clock       the clock the deadline is read from
     * @param deadline    when to give up, returning ABORT; only deep nodes look at the clock
     */
    static Int minimax(Char[] board, Color turn, Int depth, Int alpha, Int beta,
                       Boolean maximising, Color computer, Clock clock, Time deadline) {
        if (depth >= 3 && clock.now > deadline) {
            return ABORT;
        }
        // Most nodes are leaves, and listing every legal move is by far the most expensive thing
        // a node does, so leaves are scored on the spot. (A player with no moves at the very edge
        // of the search is therefore not seen as lost until one move earlier.)
        if (depth == 0) {
            return evaluate(board, computer);
        }
        Move[] moves = DraughtsRules.legalMoves(board, turn);

        // No moves means the side to move has lost. Prefer quicker wins and slower losses by
        // adjusting the score with the remaining depth.
        if (moves.empty) {
            return maximising ? -WIN_SCORE - depth : WIN_SCORE + depth;
        }

        Color next = DraughtsRules.opponent(turn);
        Int   best = maximising ? -INFINITE : INFINITE;
        for (Move move : moves) {
            (Char[] child, _) = DraughtsRules.applyMove(board, move);
            Int score = minimax(child, next, depth - 1, alpha, beta, !maximising, computer,
                                clock, deadline);
            if (score == ABORT) {
                return ABORT;
            }
            if (maximising) {
                best  = best.maxOf(score);
                alpha = alpha.maxOf(best);
            } else {
                best = best.minOf(score);
                beta = beta.minOf(best);
            }
            if (alpha >= beta) {
                break; // the other side would never allow this line
            }
        }
        return best;
    }

    /**
     * Choose a move for the side to move, at the given difficulty level.
     *
     * @return False if there is no legal move
     */
    static conditional Move chooseMove(String board, Color turn, String level, Random random) {
        Char[] root  = DraughtsRules.BoardCopy.of(board);
        Move[] moves = DraughtsRules.legalMoves(root, turn);
        if (moves.empty) {
            return False;
        }
        if (moves.size == 1) {
            return True, moves[0];
        }

        // Easier levels sometimes play a random move.
        Level settings = levelFor(level);
        if (settings.randomPercent > 0 && random.int(100) < settings.randomPercent) {
            return True, moves[random.int(moves.size)];
        }

        @Inject Clock clock;
        Time   deadline = clock.now + Duration.ofMillis(settings.budgetMs);
        Color  opponent = DraughtsRules.opponent(turn);

        // Deepen one move at a time. A finished search replaces the last one's answer, and its
        // best moves are tried first on the next, which lets pruning skip far more.
        Move[] best    = moves;
        Move[] ordered = moves;
        for (Int depth : 1 .. settings.depth) {
            Int    bestScore = -INFINITE;
            Move[] bestHere  = new Array<Move>();
            Boolean finished = True;
            for (Move move : ordered) {
                (Char[] child, _) = DraughtsRules.applyMove(root, move);
                // Passing (bestScore - 1) as alpha lets the search skip replies that cannot beat
                // or equal the best move so far. Scores are whole numbers, so ties still count.
                Int score = minimax(child, opponent, depth - 1, bestScore - 1, INFINITE,
                                    False, turn, clock, deadline);
                if (score == ABORT) {
                    finished = False;
                    break;
                }
                if (score > bestScore) {
                    bestScore = score;
                    bestHere  = new Array<Move>();
                    bestHere.add(move);
                } else if (score == bestScore) {
                    bestHere.add(move);
                }
            }
            if (!finished) {
                break;
            }
            best = bestHere;

            Move[] reordered = new Array<Move>();
            reordered.addAll(bestHere);
            for (Move move : ordered) {
                if (!bestHere.contains(move)) {
                    reordered.add(move);
                }
            }
            ordered = reordered;
        }
        // Several moves can score the same; choose one at random for variety.
        return True, best[random.int(best.size)];
    }
}
