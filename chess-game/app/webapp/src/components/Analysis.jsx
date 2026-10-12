import { useMemo, useState } from 'react';
import { useLocalPolicy } from '../lib/analyse.js';
import { useEngineCurve, leastSquares } from '../lib/engine.js';
import { FEATURES } from '../lib/model.js';
import {
  BarLineChart, CandidateBars, EvalCurve, Empty, Legend, Panel, Progress, StatTile,
  fmt, pct, signed,
} from './charts.jsx';

const BLUE = 'var(--series-1)';
const ORANGE = 'var(--series-2)';

const SIDE = { w: 'White', b: 'Black' };

/** Loss thresholds in pawns, the conventional reading of an engine's verdict on a move. */
const INACCURACY = 0.5;
const MISTAKE = 1;
const BLUNDER = 2;

export default function Analysis({ pgn, fen, positions, ply, setPly, names }) {
  const [depth, setDepth] = useState(11);
  const [engineOn, setEngineOn] = useState(true);
  const [side, setSide] = useState(null);

  const policy = useLocalPolicy({ pgn, fen });
  const engine = useEngineCurve(positions, { depth, enabled: engineOn });

  const plies = policy.plies;
  const idx = Math.min(ply, Math.max(plies.length - 1, 0));
  const decision = plies[idx] ?? null;
  const active = side ?? decision?.color ?? 'w';

  // One row per decision, with what the engine said about the position before and after it.
  const rows = useMemo(
    () =>
      plies.map((p) => {
        const before = engine.points[p.index]?.pawns;
        const after = engine.points[p.index + 1]?.pawns;
        const sign = p.color === 'w' ? 1 : -1;
        const loss =
          Number.isFinite(before) && Number.isFinite(after)
            ? Math.max(0, sign * before - sign * after)
            : null;
        const best = engine.points[p.index]?.best ?? null;
        return { ...p, key: p.ply, loss, engineBest: best, matched: best ? best === p.uci : null };
      }),
    [plies, engine.points]
  );

  const mine = useMemo(() => rows.filter((r) => r.color === active && r.surprisal != null), [rows, active]);
  const judged = useMemo(() => mine.filter((r) => r.loss != null), [mine]);

  const isGame = policy.mode === 'game';
  const stats = policy.players?.[active];
  const acpl = judged.length ? (judged.reduce((a, r) => a + r.loss, 0) / judged.length) * 100 : null;
  const agreed = judged.length ? judged.filter((r) => r.matched).length / judged.length : null;
  const count = (lo, hi) => judged.filter((r) => r.loss >= lo && r.loss < hi).length;

  const curve = useMemo(() => engine.points.map((p) => p?.pawns ?? null), [engine.points]);
  const spot = !isGame && Number.isFinite(engine.points[0]?.pawns) ? engine.points[0] : null;
  const calibration = useMemo(
    () =>
      leastSquares(
        rows
          .filter((r) => r.vPlayed != null)
          .map((r) => [r.color === 'w' ? r.vPlayed : -r.vPlayed, engine.points[r.index + 1]?.pawns])
      ),
    [rows, engine.points]
  );

  if (policy.phase === 'error') {
    return <Empty>Could not read this game: {policy.error}</Empty>;
  }
  if (policy.phase === 'idle') {
    return <Empty>Load a player's games, or the daily puzzle, to see the decision model.</Empty>;
  }

  const candidates = decision
    ? decision.candidates
        .map((c, i) => ({ ...c, p: decision.probs?.[i] ?? 0, played: i === decision.playedIndex }))
        .slice(0, 9)
    : [];
  // The move played can rank below the top few; it takes the last slot rather than vanishing.
  if (candidates.length && decision?.playedIndex >= 0 && !candidates.some((c) => c.played)) {
    const i = decision.playedIndex;
    candidates[candidates.length - 1] = {
      ...decision.candidates[i],
      p: decision.probs?.[i] ?? 0,
      played: true,
    };
  }

  return (
    <div className="analysis">
      <header className="analysis-head">
        <div>
          <h2>{isGame ? `How ${names?.[active] ?? SIDE[active]} thinks` : 'How the choice looks here'}</h2>
          <p className="caption">
            {isGame
              ? 'A weighted value function, a softmax policy over it fitted to the moves actually played, and the information cost of each choice.'
              : 'A weighted value function, a softmax policy over it, and what the engine makes of the position.'}
          </p>
        </div>
        <div className="head-controls">
          {isGame && (
            <div className="side-switch" role="group" aria-label="Side to analyse">
              {['w', 'b'].map((c) => (
                <button key={c} className={active === c ? 'on' : ''} onClick={() => setSide(c)}>
                  {names?.[c] ?? SIDE[c]}
                </button>
              ))}
            </div>
          )}
          <div className="panel-controls">
            <label>
              engine depth
              <select value={depth} onChange={(e) => setDepth(Number(e.target.value))}>
                {[8, 10, 11, 12, 13].map((d) => (
                  <option key={d} value={d}>{d}</option>
                ))}
              </select>
            </label>
            <button onClick={() => setEngineOn((on) => !on)}>{engineOn ? 'Stop' : 'Run'}</button>
          </div>
        </div>
      </header>

      {policy.phase === 'running' && (
        <div className="work">
          <span>Scoring every legal move, ply by ply…</span>
          <Progress value={policy.progress} label="Policy analysis progress" />
        </div>
      )}

      {isGame ? (
        <div className="tiles">
          {acpl != null ? (
            <StatTile hero label="Average centipawn loss" value={Math.round(acpl)} unit="cp"
                      note={`engine, depth ${depth} · ${judged.length} moves`} />
          ) : (
            <StatTile hero label="Decisiveness β̂" value={fmt(stats?.beta ?? 0, 2)}
                      note="fitted by maximum likelihood" />
          )}
          <div className="tile-grid">
            {acpl != null && (
              <StatTile label="Decisiveness β̂" value={fmt(stats?.beta ?? 0, 2)}
                        note="0 = picks at random, high = sharp" />
            )}
            <StatTile label="Effective choices" value={fmt(stats?.perplexity ?? 0, 1)}
                      note={`of ${fmt(stats?.meanBranching ?? 0, 0)} legal, on average`} />
            <StatTile label="Mean surprise" value={fmt(stats?.crossEntropy ?? 0, 2)} unit=" bits"
                      note={`${fmt(stats?.bitsExplained ?? 0, 2)} bits below picking at random`} />
            <StatTile label="Model's top move" value={pct(stats?.top1 ?? 0)}
                      note={`${pct(stats?.top3 ?? 0)} in its top three`} />
            {agreed != null && (
              <StatTile label="Engine's top move" value={pct(agreed)} note={`of ${judged.length} judged`} />
            )}
            {judged.length > 0 && (
              <StatTile label="Mistakes" value={count(MISTAKE, BLUNDER) + count(BLUNDER, Infinity)}
                        note={`${count(INACCURACY, MISTAKE)} inaccuracies · ${count(BLUNDER, Infinity)} blunders`} />
            )}
          </div>
        </div>
      ) : (
        <div className="tiles">
          {spot != null ? (
            <StatTile hero label="Engine evaluation" value={signed(spot.pawns)} unit=" pawns"
                      note={`Stockfish Online, depth ${depth}${spot.best ? ` · it would play ${spot.best}` : ''}`} />
          ) : (
            <StatTile hero label="Legal moves" value={decision?.branching ?? 0}
                      note={engine.phase === 'running' ? 'asking the engine…' : 'engine not answering'} />
          )}
          <div className="tile-grid">
            {spot != null && <StatTile label="Legal moves" value={decision?.branching ?? 0} note="branching factor" />}
            <StatTile label="Entropy" value={fmt(decision?.entropy ?? 0, 2)} unit=" bits"
                      note={`${fmt(decision?.maxEntropy ?? 0, 2)} bits if every move were equal`} />
            <StatTile label="Effective choices" value={fmt(2 ** (decision?.entropy ?? 0), 1)}
                      note="2^H — how many moves are really in play" />
            <StatTile label="Model's favourite" value={pct(decision?.probs?.[0] ?? 0)}
                      note={decision?.candidates?.[0]?.san ?? '—'} />
          </div>
        </div>
      )}

      {isGame && (
        <>
      <Panel
        title="Engine evaluation"
        caption={`Pawns from White's point of view. ${
          engine.phase === 'unavailable'
            ? 'The engine proxy is not answering, so this is empty — start the XTC server to fill it.'
            : `Stockfish Online, depth ${depth}, one position at a time — the shape appears first and sharpens as it fills. Click to jump the board.`
        }`}
        table={{
          columns: ['Move', 'Side', 'Played', 'Eval after'],
          rows: rows.map((r) => [
            r.moveNo, SIDE[r.color], r.san, signed(engine.points[r.index + 1]?.pawns ?? NaN),
          ]),
        }}
      >
        {engine.phase === 'running' && (
          <div className="work">
            <span>
              {engine.done} of {engine.total} positions
              {engine.secondsLeft > 0 && ` · about ${engine.secondsLeft}s left`}
            </span>
            <Progress value={engine.total ? engine.done / engine.total : 0} label="Engine progress" />
          </div>
        )}
        {curve.some((v) => v != null) ? (
          <EvalCurve points={curve} current={idx} onSelect={setPly} />
        ) : (
          engine.phase !== 'running' && <Empty>No engine evaluations yet.</Empty>
        )}
      </Panel>

      <Panel
        title="Cost of each move"
        caption="How much the engine's evaluation fell when the move was played, in pawns. Zero means it played as well as anything available."
        table={{
          columns: ['Move', 'Played', 'Loss (cp)', "Engine's move"],
          rows: judged.map((r) => [r.moveNo, r.san, Math.round(r.loss * 100), r.engineBest ?? '—']),
        }}
      >
        {judged.length ? (
          // Plotted over every move, not just the judged ones, so a bar always sits at its own
          // move number while the engine pass is still filling in.
          <BarLineChart rows={mine} bar={{ key: 'loss', label: 'Loss', color: ORANGE }}
                        current={decision?.ply} yMin={1} onSelect={(r) => setPly(r.index)} />
        ) : (
          <Empty>Waiting on the engine for move-by-move loss.</Empty>
        )}
      </Panel>

      <Panel
        title="Uncertainty and surprise"
        caption="Both in bits, so they share one axis. Entropy is how open the position's choice was; surprise is how improbable the move played was. Where surprise rises above entropy the move was less predictable than the position called for; where it falls below, it was the obvious one."
        legend={[
          { label: 'Surprise  −log₂ P(played)', color: ORANGE, shape: 'square' },
          { label: 'Entropy  H(p)', color: BLUE, shape: 'line' },
        ]}
        table={{
          columns: ['Move', 'Played', 'Rank', 'P(played)', 'Surprise (bits)', 'Entropy (bits)'],
          rows: mine.map((r) => [
            r.moveNo, r.san, `${r.rank} / ${r.branching}`, pct(r.pPlayed, 1),
            fmt(r.surprisal, 2), fmt(r.entropy, 2),
          ]),
        }}
      >
        {mine.length ? (
          <BarLineChart rows={mine} bar={{ key: 'surprisal', label: 'Surprise', color: ORANGE }}
                        line={{ key: 'entropy', label: 'Entropy', color: BLUE }}
                        current={decision?.ply} onSelect={(r) => setPly(r.index)}
                        format={(n) => fmt(n, 1)} />
        ) : (
          <Empty>No decisions for this side yet.</Empty>
        )}
      </Panel>
        </>
      )}

      <Panel
        title={decision?.san ? `Choice at move ${decision.moveNo}` : 'Choice at this position'}
        caption={
          decision?.san
            ? `${SIDE[decision.color]} played ${decision.san} — ranked ${decision.rank} of ${decision.branching} by the model, probability ${pct(decision.pPlayed, 1)}, ${fmt(decision.surprisal, 2)} bits of surprise.`
            : 'The policy over the moves available to the side to move.'
        }
        legend={[
          { label: 'Model probability', color: BLUE, shape: 'square' },
          { label: 'Move played', color: ORANGE, shape: 'square' },
        ]}
        table={{
          columns: ['Move', 'P', 'V (pawns)'],
          rows: candidates.map((c) => [c.san, pct(c.p, 1), signed(c.v)]),
        }}
      >
        {candidates.length ? <CandidateBars rows={candidates} /> : <Empty>No legal moves here.</Empty>}
      </Panel>

      <Panel title="The model">
        <dl className="maths">
          <div>
            <dt>V(p) = Σᵢ wᵢ φᵢ(p)</dt>
            <dd>value of a position, in pawns, from the mover's point of view</dd>
          </div>
          <div>
            <dt>P(m | p) = e<sup>βV(p∘m)</sup> ⁄ Σ<sub>m′</sub> e<sup>βV(p∘m′)</sup></dt>
            <dd>a softmax policy over the legal moves — bounded rationality, not perfect play</dd>
          </div>
          <div>
            <dt>β̂ = argmax<sub>β</sub> Σ<sub>t</sub> log P(m*<sub>t</sub> | p<sub>t</sub>)</dt>
            <dd>
              the one free parameter, fitted to the moves actually played. The log-partition is
              convex in β, so the likelihood is concave and a ternary search finds the maximum.
            </dd>
          </div>
          <div>
            <dt>H(p) = −Σ<sub>m</sub> P log₂ P</dt>
            <dd>bits of uncertainty in the choice; H<sub>max</sub> = log₂|L(p)| if every move were equal</dd>
          </div>
          <div>
            <dt>S(m*) = −log₂ P(m*)</dt>
            <dd>bits of surprise at the move played</dd>
          </div>
          <div>
            <dt>ℒ = N⁻¹ Σ<sub>t</sub> S<sub>t</sub> , perplexity = 2<sup>ℒ</sup></dt>
            <dd>mean surprise per move, and the effective number of moves being weighed</dd>
          </div>
          <div>
            <dt>ℒ = N⁻¹ Σ<sub>t</sub> H(p<sub>t</sub>)</dt>
            <dd>
              at the fitted β̂ these two means are equal, not approximately: setting the
              derivative of the likelihood to zero forces Σ V(m*) = Σ E<sub>P</sub>[V], and that
              is exactly the difference between the two sums. Per move they still differ, and
              that gap is what the chart above plots.
            </dd>
          </div>
        </dl>

        <table className="features">
          <caption>The six features, and the weights that put them in pawns</caption>
          <thead>
            <tr>
              <th scope="col">φ</th>
              <th scope="col">Feature</th>
              <th scope="col">w</th>
              <th scope="col">Measured as</th>
            </tr>
          </thead>
          <tbody>
            {FEATURES.map((f) => (
              <tr key={f.key}>
                <td>{f.symbol}</td>
                <td>{f.label}</td>
                <td className="num">{f.w}</td>
                <td className="note">{f.note} ({f.unit})</td>
              </tr>
            ))}
          </tbody>
        </table>

        {calibration ? (
          <p className="calibration">
            Calibrated against the engine over {calibration.n} positions:{' '}
            <strong>engine ≈ {fmt(calibration.intercept, 2)} + {fmt(calibration.slope, 2)}·V</strong>,
            r² = {fmt(calibration.r2, 2)}, RMSE {fmt(calibration.rmse, 2)} pawns. The linear model
            tracks the engine's direction but not its tactics — which is the point: it is a model of
            a person, not a search.
          </p>
        ) : (
          <p className="calibration">
            Calibration against the engine appears once enough positions have been evaluated.
          </p>
        )}
      </Panel>
    </div>
  );
}
