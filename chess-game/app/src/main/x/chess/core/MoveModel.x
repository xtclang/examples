import db.models.CastlingRights;
import db.models.MoveHistoryEntry;
import validation.CheckDetection;
import validation.CheckDetection.MovePair;
import core.ChessGame.MoveOutcome;

/**
 * A direct port of the frontend's "transparent client-side model" of how a player chooses a
 * move (originally webapp/src/lib/model.js + the model-scoring parts of
 * webapp/src/lib/analyse.js). The model itself is unchanged -- material, placement, pawn
 * structure, king safety, mobility and tempo features weighted into a linear value, and a
 * softmax policy fitted to the moves actually played by maximum likelihood. Only where it runs
 * changed: here, instead of in the browser.
 *
 *   V(p)      = wᵀφ(p)                             linear value of a position
 *   P(m | p)  = softmax over legal m of β·V(p∘m)    bounded-rationality policy
 *   β̂         = argmax_β Σ_t log P(m*_t | p_t)      fitted to the moves actually played
 */
@Abstract
class MoveModel {
    // ----- feature weights (pawns per unit of feature) ---------------------

    static Double MATERIAL_W  =  0.010;
    static Double PLACEMENT_W =  0.010;
    static Double STRUCTURE_W = -0.180;
    static Double SHIELD_W    =  0.140;
    static Double RESTRAINT_W = -0.015;
    static Double TEMPO_W     =  0.300;
    static Double EXPOSURE_W  = -0.010;

    /** Pawns; large enough to dominate, small enough for a stable softmax. */
    static Double MATE = 30.0;

    /** Beta used when there are no played moves yet to fit one from. */
    static Double DEFAULT_BETA = 2.0;

    static Double LN2 = 0.6931471805599453;

    // ----- piece values and piece-square tables -----------------------------

    static Char upper(Char c) = ('a' <= c <= 'z') ? (c.toInt() - 32).toChar() : c;

    static Int pieceValue(Char pieceUpper) {
        switch (pieceUpper) {
        case 'P': return 100;
        case 'N': return 320;
        case 'B': return 330;
        case 'R': return 500;
        case 'Q': return 900;
        default:  return 0; // king
        }
    }

    // Piece-square tables in centipawns, row 0 = rank 8, matching this codebase's board layout.
    static Int[] PST_P = [
        0, 0, 0, 0, 0, 0, 0, 0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
        5, 5, 10, 25, 25, 10, 5, 5,
        0, 0, 0, 20, 20, 0, 0, 0,
        5, -5, -10, 0, 0, -10, -5, 5,
        5, 10, 10, -20, -20, 10, 10, 5,
        0, 0, 0, 0, 0, 0, 0, 0];

    static Int[] PST_N = [
        -50, -40, -30, -30, -30, -30, -40, -50,
        -40, -20, 0, 0, 0, 0, -20, -40,
        -30, 0, 10, 15, 15, 10, 0, -30,
        -30, 5, 15, 20, 20, 15, 5, -30,
        -30, 0, 15, 20, 20, 15, 0, -30,
        -30, 5, 10, 15, 15, 10, 5, -30,
        -40, -20, 0, 5, 5, 0, -20, -40,
        -50, -40, -30, -30, -30, -30, -40, -50];

    static Int[] PST_B = [
        -20, -10, -10, -10, -10, -10, -10, -20,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -10, 0, 5, 10, 10, 5, 0, -10,
        -10, 5, 5, 10, 10, 5, 5, -10,
        -10, 0, 10, 10, 10, 10, 0, -10,
        -10, 10, 10, 10, 10, 10, 10, -10,
        -10, 5, 0, 0, 0, 0, 5, -10,
        -20, -10, -10, -10, -10, -10, -10, -20];

    static Int[] PST_R = [
        0, 0, 0, 0, 0, 0, 0, 0,
        5, 10, 10, 10, 10, 10, 10, 5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        0, 0, 0, 5, 5, 0, 0, 0];

    static Int[] PST_Q = [
        -20, -10, -10, -5, -5, -10, -10, -20,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -10, 0, 5, 5, 5, 5, 0, -10,
        -5, 0, 5, 5, 5, 5, 0, -5,
        0, 0, 5, 5, 5, 5, 0, -5,
        -10, 5, 5, 5, 5, 5, 0, -10,
        -10, 0, 5, 0, 0, 0, 0, -10,
        -20, -10, -10, -5, -5, -10, -10, -20];

    static Int[] PST_K = [
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -20, -30, -30, -40, -40, -30, -30, -20,
        -10, -20, -20, -20, -20, -20, -20, -10,
        20, 20, 0, 0, 0, 0, 20, 20,
        20, 30, 10, 0, 0, 10, 30, 20];

    static Int pstValue(Char pieceUpper, Int boardIndex, Color color) {
        Int row = BoardUtils.getRank(boardIndex);
        Int col = BoardUtils.getFile(boardIndex);
        Int effectiveRow = color == White ? row : 7 - row;
        Int[] table;
        switch (pieceUpper) {
        case 'P': table = PST_P; break;
        case 'N': table = PST_N; break;
        case 'B': table = PST_B; break;
        case 'R': table = PST_R; break;
        case 'Q': table = PST_Q; break;
        default:  table = PST_K; break;
        }
        return table[effectiveRow * 8 + col];
    }

    // ----- scanning a position ----------------------------------------------

    static const ScanResult(Int material, Int placement, Int[] pawnFiles, Int kingIndex);

    static ScanResult scanSide(String board, Color side) {
        Int material = 0;
        Int placement = 0;
        Int[] pawnFiles = new Int[8](_ -> 0);
        Int kingIndex = -1;
        for (Int i : 0 ..< 64) {
            Char piece = board[i];
            if (piece == '.' || BoardUtils.colorOf(piece) != side) {
                continue;
            }
            Char up = upper(piece);
            material += pieceValue(up);
            placement += pstValue(up, i, side);
            if (up == 'P') {
                Int file = BoardUtils.getFile(i);
                pawnFiles[file] = pawnFiles[file] + 1;
            } else if (up == 'K') {
                kingIndex = i;
            }
        }
        return new ScanResult(material, placement, pawnFiles, kingIndex);
    }

    /** Doubled pawns plus pawns with no friendly pawn on either neighbouring file. */
    static Int structurePenalty(Int[] pawnFiles) {
        Int penalty = 0;
        for (Int f : 0 ..< 8) {
            Int n = pawnFiles[f];
            if (n == 0) {
                continue;
            }
            penalty += n - 1;
            Int left  = f > 0 ? pawnFiles[f - 1] : 0;
            Int right = f < 7 ? pawnFiles[f + 1] : 0;
            if (left == 0 && right == 0) {
                penalty += n;
            }
        }
        return penalty;
    }

    /** Own pawns on the king's file or either neighbour, within two ranks in front. */
    static Int shieldCount(String board, Int kingIndex, Color color) {
        if (kingIndex < 0) {
            return 0;
        }
        Int kingRow = BoardUtils.getRank(kingIndex);
        Int kingCol = BoardUtils.getFile(kingIndex);
        Int forward = color == White ? -1 : 1;
        Int count = 0;
        for (Int df : -1 ..< 2) {
            Int c = kingCol + df;
            if (c < 0 || c > 7) {
                continue;
            }
            for (Int step : 1 ..< 3) {
                Int r = kingRow + forward * step;
                if (r < 0 || r > 7) {
                    continue;
                }
                Char cell = board[r * 8 + c];
                if (cell != '.' && upper(cell) == 'P' && BoardUtils.colorOf(cell) == color) {
                    count++;
                }
            }
        }
        return count;
    }

    // ----- value of a position after a move ---------------------------------

    static const Features(Int material, Int placement, Int structure, Int shield, Int restraint,
                          Int tempo, Int exposure);

    /**
     * Feature vector of the position reached *after* `mover` has moved, written from `mover`'s
     * point of view. `after` must be sitting on that position, so the side to move is the
     * opponent.
     */
    static Features featureVector(GameRecord after, Color mover, Boolean gaveCheck) {
        Color opponent = mover == White ? Black : White;
        ScanResult mine   = scanSide(after.board, mover);
        ScanResult theirs = scanSide(after.board, opponent);

        // The opponent's reply list is read twice: how many options they have, and the best
        // exchange they can win from it -- without this the model has no idea a piece is
        // hanging, and mispredicts almost every real move.
        MovePair[] replies = CheckDetection.getAllLegalMoves(
                after.board, opponent, after.castlingRights, after.enPassantTarget);
        Int exposure = 0;
        for (MovePair reply : replies) {
            Char target = after.board[reply.toSquare];
            if (target == '.') {
                continue;
            }
            Char moving = after.board[reply.fromSquare];
            Int gain = pieceValue(upper(target)) - pieceValue(upper(moving));
            if (gain > exposure) {
                exposure = gain;
            }
        }

        return new Features(
                mine.material - theirs.material,
                mine.placement - theirs.placement,
                structurePenalty(mine.pawnFiles) - structurePenalty(theirs.pawnFiles),
                shieldCount(after.board, mine.kingIndex, mover)
                        - shieldCount(after.board, theirs.kingIndex, opponent),
                replies.size,
                gaveCheck ? 1 : 0,
                exposure);
    }

    static Double value(Features f) {
        return MATERIAL_W  * f.material.toFloat64()
             + PLACEMENT_W * f.placement.toFloat64()
             + STRUCTURE_W * f.structure.toFloat64()
             + SHIELD_W    * f.shield.toFloat64()
             + RESTRAINT_W * f.restraint.toFloat64()
             + TEMPO_W     * f.tempo.toFloat64()
             + EXPOSURE_W  * f.exposure.toFloat64();
    }

    // ----- scoring every legal move from a position -------------------------

    static const Candidate(String san, String fromSquare, String toSquare, String uci, Double v, String? terminal);

    static const PositionScore(String color, Candidate[] candidates);

    /**
     * Every legal move from `fen`, valued by the model from the mover's point of view and
     * sorted best first. Always promotes to a queen, matching the rest of this app (see
     * [ChessGame.applyMove]), rather than scoring all four promotion choices separately.
     */
    static PositionScore scorePosition(String fen) {
        GameRecord before = FenParser.fromFen(fen);
        Color      color  = before.turn;
        MovePair[] legal  = CheckDetection.getAllLegalMoves(
                before.board, before.turn, before.castlingRights, before.enPassantTarget);

        Candidate[] candidates = new Candidate[];
        for (MovePair mp : legal) {
            String fromAlg = BoardUtils.toAlgebraic(mp.fromSquare);
            String toAlg   = BoardUtils.toAlgebraic(mp.toSquare);
            MoveOutcome outcome = ChessLogic.applyHumanMove(before, fromAlg, toAlg, Null);
            if (!outcome.ok) {
                continue;
            }
            GameRecord      after = outcome.record;
            MoveHistoryEntry last = after.moveHistory[after.moveHistory.size - 1];

            Double  v;
            String? terminal;
            if (last.isCheckmate) {
                v = MATE;
                terminal = "mate";
            } else if (after.status == GameStatus.Stalemate || after.status == GameStatus.InsufficientMaterial
                    || after.status == GameStatus.FiftyMoveRule || after.status == GameStatus.ThreefoldRepetition) {
                v = 0.0;
                terminal = "draw";
            } else {
                v = value(featureVector(after, color, last.isCheck));
                terminal = Null;
            }

            candidates = candidates.addAll([new Candidate(last.notation, fromAlg, toAlg,
                    fromAlg + toAlg, v, terminal)]);
        }

        candidates = candidates.sorted((a, b) -> {
            Ordered byValue = b.v <=> a.v;
            return byValue == Equal ? a.san <=> b.san : byValue;
        });

        return new PositionScore(color == White ? "w" : "b", candidates);
    }

    // ----------------------------------------------------------- the policy

    /** Numerically safe softmax of beta*v. */
    static Double[] softmax(Double[] vs, Double beta) {
        Double max = Double.NegativeInfinity;
        for (Double v : vs) {
            Double scaled = beta * v;
            if (scaled > max) {
                max = scaled;
            }
        }
        Double sum = 0.0;
        Double[] out = new Double[vs.size](_ -> 0.0);
        for (Int i : 0 ..< vs.size) {
            out[i] = (beta * vs[i] - max).exp();
            sum += out[i];
        }
        for (Int i : 0 ..< out.size) {
            out[i] = out[i] / sum;
        }
        return out;
    }

    /** log P(played | beta) for one decision, via log-sum-exp. */
    static Double logProb(Double[] vs, Int playedIndex, Double beta) {
        Double max = Double.NegativeInfinity;
        for (Double v : vs) {
            Double scaled = beta * v;
            if (scaled > max) {
                max = scaled;
            }
        }
        Double sum = 0.0;
        for (Double v : vs) {
            sum += (beta * v - max).exp();
        }
        return beta * vs[playedIndex] - (max + sum.log());
    }

    static const DecisionRow(Double[] vs, Int playedIndex);

    static Double logLikelihood(DecisionRow[] rows, Double beta) {
        Double total = 0.0;
        for (DecisionRow row : rows) {
            total += logProb(row.vs, row.playedIndex, beta);
        }
        return total;
    }

    static const BetaFit(Double beta, Double logLik, Double perMove);

    /**
     * Maximum-likelihood beta. The log-partition function is convex in beta, so the
     * log-likelihood is concave and a ternary search finds the global optimum.
     */
    static BetaFit fitBeta(DecisionRow[] rows, Double lo = 0.0, Double hi = 8.0, Int iterations = 60) {
        if (rows.size == 0) {
            return new BetaFit(0.0, 0.0, 0.0);
        }
        for (Int i : 0 ..< iterations) {
            Double a = lo + (hi - lo) / 3.0;
            Double b = hi - (hi - lo) / 3.0;
            if (logLikelihood(rows, a) < logLikelihood(rows, b)) {
                lo = a;
            } else {
                hi = b;
            }
        }
        Double beta   = (lo + hi) / 2.0;
        Double logLik = logLikelihood(rows, beta);
        return new BetaFit(beta, logLik, logLik / rows.size.toFloat64());
    }

    static Double log2(Double x) = x.log() / LN2;

    static Double entropyBits(Double[] ps) {
        Double h = 0.0;
        for (Double p : ps) {
            if (p > 0.0) {
                h -= p * p.log();
            }
        }
        return h / LN2;
    }

    static Double? meanOf(Double[] xs) {
        if (xs.size == 0) {
            return Null;
        }
        Double sum = 0.0;
        for (Double x : xs) {
            sum += x;
        }
        return sum / xs.size.toFloat64();
    }

    static Double? shareOf(Boolean[] flags) {
        if (flags.size == 0) {
            return Null;
        }
        Int count = 0;
        for (Boolean f : flags) {
            if (f) {
                count++;
            }
        }
        return count.toFloat64() / flags.size.toFloat64();
    }
}
