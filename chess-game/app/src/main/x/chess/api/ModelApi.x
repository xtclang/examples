import core.MoveModel;
import core.MoveModel.Candidate;
import core.MoveModel.PositionScore;
import core.MoveModel.DecisionRow;
import core.MoveModel.BetaFit;

/**
 * ModelApi Service
 *
 * Serves the "Insights" panel's move-choice model (see [MoveModel]): given a game's positions
 * and the moves actually played, scores every legal move at each position and fits the softmax
 * policy's beta per side by maximum likelihood. This used to run entirely in the browser
 * (webapp/src/lib/model.js); the shape returned here matches what that code produced, so the
 * frontend only had to change where it asks for the numbers, not how it renders them.
 *
 * Endpoints:
 * - POST /api/model/analyse
 */
@WebService("/api/model")
service ModelApi {
    /**
     * POST /api/model/analyse
     *
     * @param request the game's positions (`fens`, one per ply including the start) and the
     *                move actually played out of each one (`playedUci`, length `fens.size - 1`,
     *                as `fromto` or `fromtopromo`; only the first four characters are matched,
     *                since every move in this app auto-promotes to a queen)
     * @return one [Decision] per position, and the fitted policy's per-side summary stats
     */
    @Post("analyse")
    @Produces(Json)
    @HttpsRequired
    AnalysisResult analyse(@BodyParam AnalyseRequest request) {
        Partial[] partials = new Partial[];
        for (Int i : 0 ..< request.fens.size) {
            PositionScore score = MoveModel.scorePosition(request.fens[i]);
            Double[] vs = new Double[score.candidates.size](j -> score.candidates[j].v);

            String playedKey = i < request.playedUci.size ? request.playedUci[i] : "";
            Int playedIndex = -1;
            if (playedKey.size >= 4) {
                String key = playedKey[0 ..< 4];
                for (Int j : 0 ..< score.candidates.size) {
                    Candidate candidate = score.candidates[j];
                    if (candidate.fromSquare + candidate.toSquare == key) {
                        playedIndex = j;
                        break;
                    }
                }
            }

            Double? vPlayed = playedIndex >= 0 ? vs[playedIndex] : Null;
            Int?    rank    = playedIndex >= 0 ? playedIndex + 1 : Null;
            Double? regret  = Null;
            if (playedIndex >= 0 && vs.size > 0) {
                regret = vs[0] - vs[playedIndex];
            }

            partials = partials.addAll([new Partial(request.fens[i], score.color, score.candidates,
                    vs, playedIndex, rank, vPlayed, regret)]);
        }

        DecisionRow[] whiteRows = new DecisionRow[];
        DecisionRow[] blackRows = new DecisionRow[];
        for (Partial p : partials) {
            if (p.playedIndex >= 0 && p.vs.size > 1) {
                DecisionRow row = new DecisionRow(p.vs, p.playedIndex);
                if (p.color == "w") {
                    whiteRows = whiteRows.addAll([row]);
                } else {
                    blackRows = blackRows.addAll([row]);
                }
            }
        }

        BetaFit whiteFit = whiteRows.size > 0
                ? MoveModel.fitBeta(whiteRows) : new BetaFit(MoveModel.DEFAULT_BETA, 0.0, 0.0);
        BetaFit blackFit = blackRows.size > 0
                ? MoveModel.fitBeta(blackRows) : new BetaFit(MoveModel.DEFAULT_BETA, 0.0, 0.0);

        Decision[] decisions = new Decision[];
        for (Partial p : partials) {
            Double beta  = p.color == "w" ? whiteFit.beta : blackFit.beta;
            Double[] probs = MoveModel.softmax(p.vs, beta);
            Double entropy = MoveModel.entropyBits(probs);
            Double maxEntropy = p.vs.size > 0 ? MoveModel.log2(p.vs.size.toFloat64()) : 0.0;

            Double? pPlayed   = p.playedIndex >= 0 ? probs[p.playedIndex] : Null;
            Double? surprisal = Null;
            if (Double played ?= pPlayed) {
                if (played > 0.0) {
                    surprisal = -MoveModel.log2(played);
                }
            }

            decisions = decisions.addAll([new Decision(p.fen, p.color, p.candidates, p.vs,
                    p.vs.size, p.playedIndex, p.rank, p.vPlayed, p.regret,
                    beta, probs, entropy, maxEntropy, pPlayed, surprisal)]);
        }

        Players players = new Players(
                playerStats("w", whiteFit, whiteRows.size, decisions),
                playerStats("b", blackFit, blackRows.size, decisions));
        return new AnalysisResult(decisions, players);
    }

    /**
     * Aggregates the per-side numbers [MoveModel]'s policy produces: how often the model's
     * favourite move matches what was actually played, how surprised it was on average, and so
     * on -- computed over the same set of decisions `fitBeta` was fitted to (a played move, with
     * more than one legal option).
     */
    private static PlayerStats playerStats(String color, BetaFit fit, Int rowCount, Decision[] decisions) {
        Double[]  surprisals = new Double[];
        Double[]  uniformBitsList = new Double[];
        Double[]  entropies = new Double[];
        Double[]  branchings = new Double[];
        Boolean[] top1Flags = new Boolean[];
        Boolean[] top3Flags = new Boolean[];

        for (Decision d : decisions) {
            if (d.color != color || d.vs.size <= 1) {
                continue;
            }
            if (Double surprisal ?= d.surprisal) {
                surprisals = surprisals.addAll([surprisal]);
                uniformBitsList = uniformBitsList.addAll([d.maxEntropy]);
                entropies = entropies.addAll([d.entropy]);
                branchings = branchings.addAll([d.branching.toFloat64()]);
                top1Flags = top1Flags.addAll([d.rank == 1]);
                Boolean inTop3 = False;
                if (Int rank ?= d.rank) {
                    inTop3 = rank <= 3;
                }
                top3Flags = top3Flags.addAll([inTop3]);
            }
        }

        Double? crossEntropy = MoveModel.meanOf(surprisals);
        Double? uniformBits  = MoveModel.meanOf(uniformBitsList);
        Double? bitsExplained = Null;
        if (Double cross ?= crossEntropy) {
            if (Double uniform ?= uniformBits) {
                bitsExplained = uniform - cross;
            }
        }
        Double? perplexity = Null;
        if (Double cross ?= crossEntropy) {
            perplexity = (cross * MoveModel.LN2).exp();
        }

        return new PlayerStats(fit.beta, fit.logLik, fit.perMove, rowCount > 0, rowCount,
                crossEntropy, perplexity, uniformBits, bitsExplained,
                MoveModel.meanOf(entropies), MoveModel.meanOf(branchings),
                MoveModel.shareOf(top1Flags), MoveModel.shareOf(top3Flags));
    }

    // ----- request/response shapes ------------------------------------------

    static const AnalyseRequest(String[] fens, String[] playedUci);

    /** A position mid-way through scoring, before the per-side beta is known. */
    private static const Partial(String fen, String color, Candidate[] candidates, Double[] vs,
                                 Int playedIndex, Int? rank, Double? vPlayed, Double? regret);

    static const Decision(String fen,
                          String color,
                          Candidate[] candidates,
                          Double[] vs,
                          Int branching,
                          Int playedIndex,
                          Int? rank,
                          Double? vPlayed,
                          Double? regret,
                          Double beta,
                          Double[] probs,
                          Double entropy,
                          Double maxEntropy,
                          Double? pPlayed,
                          Double? surprisal);

    static const PlayerStats(Double beta,
                             Double logLik,
                             Double perMove,
                             Boolean fitted,
                             Int moves,
                             Double? crossEntropy,
                             Double? perplexity,
                             Double? uniformBits,
                             Double? bitsExplained,
                             Double? meanEntropy,
                             Double? meanBranching,
                             Double? top1,
                             Double? top3);

    static const Players(PlayerStats w, PlayerStats b);

    static const AnalysisResult(Decision[] decisions, Players players);
}
