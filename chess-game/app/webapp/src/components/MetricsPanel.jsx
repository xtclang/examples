import { useMemo, useState } from 'react';
import { useLocalPolicy } from '../lib/analyse.js';
import { leastSquares, useEngineEvaluations } from '../lib/engine.js';
import { describeEvaluation, moveRows, sideSummary, winChance } from '../lib/insights.js';
import {
  CalibrationChart,
  COLORS,
  ComplexityChart,
  EvalChart,
  fmt,
  PolicyChart,
  pct,
  sideColor,
  signed,
  ThinkingChart,
  WinLostChart,
} from './charts.jsx';
import { MovesTable } from './MovesTable.jsx';
import { ChartCard, Empty, Metric, OutcomeBar, Progress, Section, Segmented, Thinking } from './ui.jsx';

const SIDE = { w: 'White', b: 'Black' };

/** The win chance split between the sides, as a thin pill bar: White in gold, Black in blue. */
function WinBar({ pawns }) {
  const white = Number.isFinite(pawns) ? Math.round(winChance(pawns)) : 50;
  return (
    <div className="winbar">
      <OutcomeBar
        label={`Win chance: White ${white}%, Black ${100 - white}%`}
        segments={[
          { label: 'white', value: white, color: COLORS.white },
          { label: 'black', value: 100 - white, color: COLORS.black },
        ]}
      />
    </div>
  );
}

/**
 * One side's game on a card, the way the reference ranks its agents: the name and how many
 * moves were judged, the accuracy as the big number, the split of good moves and mistakes as a
 * thin bar with its counts, then a row of averages under a rule.
 */
function SideCard({ name, color, summary }) {
  const good = Math.max(0, summary.judged - summary.inaccuracies - summary.mistakes - summary.blunders);
  const waiting = summary.judged === 0;
  return (
    <article className="side-card">
      <header className="side-card-head">
        <span className="side-card-name">
          <span className="key key-dot" style={{ background: sideColor(color) }} aria-hidden="true" />
          {name}
        </span>
        <span className="label">{summary.judged} of {summary.moves} judged</span>
      </header>
      <div className="side-card-figure">
        <span className="side-card-value" key={String(summary.accuracy)}>
          {waiting ? '—' : `${Math.round(summary.accuracy)}%`}
        </span>
        <span className="side-card-caption">accuracy</span>
      </div>
      <OutcomeBar
        segments={[
          { label: 'good', value: good, color: sideColor(color) },
          { label: 'inacc.', value: summary.inaccuracies, color: 'color-mix(in srgb, var(--muted) 55%, transparent)' },
          { label: 'mistake', value: summary.mistakes, color: 'var(--muted)' },
          { label: 'blunder', value: summary.blunders, color: 'var(--blunder)' },
        ]}
      />
      <footer className="side-card-foot">
        <span>acpl {waiting ? '—' : Math.round(summary.acpl)}</span>
        <span>engine {waiting ? '—' : pct(summary.engineMatch, 0)}</span>
        <span>worst {summary.worst ? summary.worst.san : '—'}</span>
      </footer>
    </article>
  );
}

function EngineStatus({ engine, onToggle, enabled }) {
  if (!enabled) {
    return (
      <button className="pill" onClick={onToggle}>
        <span className="dot dot-off" /> Engine paused
      </button>
    );
  }
  if (engine.unavailable) {
    return (
      <span className="pill pill-warn" title="The server's /api/engine proxy is not answering">
        <span className="dot dot-warn" /> Engine offline
      </span>
    );
  }
  if (engine.running) {
    return (
      <button className="pill" onClick={onToggle} title="Pause engine analysis">
        <Thinking label="Evaluating" /> {engine.done}/{engine.total}
        {engine.secondsLeft > 0 && <span className="pill-dim"> · ~{engine.secondsLeft}s</span>}
      </button>
    );
  }
  return (
    <button className="pill" onClick={onToggle} title="Pause engine analysis">
      <span className="dot dot-live" /> Live
    </button>
  );
}

/**
 * Everything the right-hand pane shows about a game, built from one shape: the positions, the
 * moves between them, and which position is on the board. Play and Review both feed it, so the
 * same numbers mean the same thing in both.
 */
export function MetricsPanel({ mode, positions, moves, current, names, onSeek, onCollapse, onGuide }) {
  const playing = mode === 'play';
  const [depth, setDepth] = useState(11);
  const [engineOn, setEngineOn] = useState(true);
  const [chosenSide, setChosenSide] = useState('w');
  const side = playing ? 'w' : chosenSide;

  const policy = useLocalPolicy(positions, moves);
  const engine = useEngineEvaluations(positions, { depth, enabled: engineOn, current });

  const rows = useMemo(() => moveRows(moves, policy.decisions, engine.points), [moves, policy.decisions, engine.points]);
  const mine = useMemo(() => rows.filter((r) => r.color === side), [rows, side]);
  const summary = useMemo(() => sideSummary(rows, side, policy.players?.[side]), [rows, side, policy.players]);
  const whiteSummary = useMemo(() => sideSummary(rows, 'w', policy.players?.w), [rows, policy.players]);
  const blackSummary = useMemo(() => sideSummary(rows, 'b', policy.players?.b), [rows, policy.players]);

  const here = engine.points[current] ?? null;
  const decision = policy.decisions[current] ?? null;
  const playedHere = moves[current] ?? null;

  const candidates = useMemo(() => {
    if (!decision?.probs) return [];
    const list = decision.candidates.map((c, i) => ({ ...c, p: decision.probs[i], played: i === decision.playedIndex }));
    const top = list.slice(0, 8);
    const played = list.find((c) => c.played);
    if (played && !top.includes(played)) top[top.length - 1] = played;
    return top;
  }, [decision]);

  const pairs = useMemo(
    () =>
      moves
        .map((m, k) => {
          const d = policy.decisions[k];
          const after = engine.points[k + 1]?.pawns;
          if (!d || d.vPlayed === null || !Number.isFinite(after)) return null;
          return [m.color === 'w' ? d.vPlayed : -d.vPlayed, after];
        })
        .filter(Boolean),
    [moves, policy.decisions, engine.points]
  );
  const fit = useMemo(() => leastSquares(pairs), [pairs]);

  const who = playing ? 'You' : names?.[side] ?? SIDE[side];
  const evaluating = engineOn && !here && !engine.unavailable;
  const hasMoves = moves.length > 0;

  return (
    <div className="metrics">
      <header className="metrics-head">
        <div className="metrics-title">
          <h1>Insights</h1>
          <EngineStatus engine={engine} enabled={engineOn} onToggle={() => setEngineOn((on) => !on)} />
        </div>
        <div className="metrics-tools">
          <label className="select">
            <span>Depth</span>
            <select value={depth} onChange={(e) => setDepth(Number(e.target.value))} aria-label="Engine depth">
              {[8, 10, 11, 12, 13].map((d) => (
                <option key={d} value={d}>{d}</option>
              ))}
            </select>
          </label>
          <button className="icon-btn" onClick={onCollapse} aria-label="Hide insights" title="Hide insights (focus on the board)">
            <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
              <path d="M6 3l5 5-5 5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </div>
      </header>

      {engine.running && (
        <Progress value={engine.total ? engine.done / engine.total : 0} label="Engine evaluation progress" />
      )}

      <Section id="position" title="This position" meta={playedHere ? `before ${playedHere.san}` : undefined}>
        <div className="metric-grid">
          <div className="metric metric-hero" style={{ '--i': 0 }}>
            <span className="metric-label">Engine evaluation</span>
            {evaluating ? (
              <span className="metric-value metric-hero-value">
                <Thinking label="Asking the engine" />
              </span>
            ) : (
              <span className="metric-value metric-hero-value" key={here?.pawns ?? 'none'}>
                {here ? signed(here.pawns, 2) : '—'}
                {here && <span className="metric-unit">pawns</span>}
              </span>
            )}
            <span className="metric-note">
              {here ? describeEvaluation(here.pawns, here.mate) : engine.unavailable ? 'Engine offline' : ' '}
              {here?.best && <> · Stockfish would play <code>{here.best}</code></>}
            </span>
            <WinBar pawns={here?.pawns} />
          </div>
          <Metric index={1} label="Legal moves" value={decision?.branching ?? '—'} loading={!decision} note="the branching factor" />
          <Metric
            index={2}
            label="Uncertainty"
            value={fmt(decision?.entropy, 2)}
            unit=" bits"
            loading={!decision?.probs}
            note={decision ? `of ${fmt(decision.maxEntropy, 2)} possible` : null}
          />
          <Metric
            index={3}
            label="Real options"
            value={decision?.probs ? fmt(2 ** decision.entropy, 1) : '—'}
            loading={!decision?.probs}
            note="moves genuinely in play"
          />
          <Metric
            index={4}
            label="Model's pick"
            value={decision?.candidates?.[0]?.san ?? '—'}
            loading={!decision?.probs}
            note={decision?.probs ? `${pct(decision.probs[0], 0)} likely` : null}
          />
        </div>
      </Section>

      <Section
        id="game"
        title={playing ? 'Your game' : 'The game'}
        meta={hasMoves ? `${summary.judged}/${summary.moves} moves judged` : undefined}
        actions={
          !playing && (
            <Segmented
              size="sm"
              label="Side"
              value={side}
              onChange={setChosenSide}
              options={[
                { value: 'w', label: names?.w ?? 'White' },
                { value: 'b', label: names?.b ?? 'Black' },
              ]}
            />
          )
        }
      >
        {!hasMoves ? (
          <Empty>{playing ? 'Make your first move — the game charts start building from there.' : 'No moves in this position.'}</Empty>
        ) : (
          <>
            <div className="side-cards">
              <SideCard name={playing ? 'You' : names?.w ?? 'White'} color="w" summary={whiteSummary} />
              <SideCard name={playing ? 'Engine' : names?.b ?? 'Black'} color="b" summary={blackSummary} />
            </div>

            <ChartCard
              index={0}
              title="Evaluation"
              caption="Who stood better, move by move. Above the line White, below it Black. Click to jump the board."
              legend={[
                { label: 'White better', color: COLORS.white, shape: 'square' },
                { label: 'Black better', color: COLORS.black, shape: 'square' },
              ]}
            >
              <EvalChart points={engine.points} current={current} onSeek={onSeek} />
            </ChartCard>

            <ChartCard
              index={1}
              title="Cost of each move"
              caption={`Win chance ${who === 'You' ? 'you' : who} gave away with each move. A bar that crosses a line earns the name on it.`}
            >
              {summary.judged ? (
                <WinLostChart rows={mine} current={current} onSeek={onSeek} />
              ) : (
                <Empty>Waiting on the engine…</Empty>
              )}
            </ChartCard>
          </>
        )}
      </Section>

      <Section
        id="thinking"
        title={playing ? 'How you think' : `How ${who} thinks`}
        meta={summary.beta !== null ? `β̂ = ${fmt(summary.beta, 2)}` : undefined}
      >
        {!hasMoves || summary.beta === null ? (
          <Empty>{playing ? 'Your thinking profile appears once there are a few of your moves to fit it to.' : 'The thinking profile appears once there are a few moves to fit it to.'}</Empty>
        ) : (
          <>
            <div className="metric-grid metric-grid-4">
              <Metric index={0} label="Decisiveness β̂" value={fmt(summary.beta, 2)} note="0 = random, high = sharp" />
              <Metric index={1} label="Options weighed" value={fmt(summary.perplexity, 1)} note={`of ${fmt(summary.meanBranching, 0)} legal, on average`} />
              <Metric index={2} label="Mean surprise" value={fmt(summary.crossEntropy, 2)} unit=" bits" note={`${fmt(summary.bitsExplained, 2)} bits below random`} />
              <Metric index={3} label="Model's first choice" value={pct(summary.top1, 0)} note={`${pct(summary.top3, 0)} in its top three`} />
            </div>

            <ChartCard
              index={2}
              title="Surprise and uncertainty"
              caption="Bars: how unexpected each move was. Line: how open the position was. A bar above the line is a move the position didn't call for."
              legend={[
                { label: 'Surprise', color: sideColor(side), shape: 'square' },
                { label: 'Uncertainty', color: COLORS.ink, shape: 'line' },
              ]}
            >
              <ThinkingChart rows={mine} current={current} onSeek={onSeek} />
            </ChartCard>

            <ChartCard
              index={3}
              title="Complexity"
              caption="Legal moves each side had at every turn. Peaks are where the game got sharp."
              legend={[
                { label: 'White', color: COLORS.white, shape: 'line' },
                { label: 'Black', color: COLORS.black, shape: 'line' },
              ]}
            >
              <ComplexityChart decisions={policy.decisions} />
            </ChartCard>
          </>
        )}
      </Section>

      <Section
        id="choice"
        title="The choice here"
        meta={decision ? `${SIDE[decision.color]} to move` : undefined}
      >
        {candidates.length ? (
          <ChartCard
            index={4}
            title={playedHere ? `${SIDE[decision.color]} played ${playedHere.san}` : 'Moves the model would consider'}
            caption={
              playedHere && decision.rank
                ? `Ranked ${decision.rank} of ${decision.branching} by the model — ${pct(decision.pPlayed, 1)} likely, ${fmt(decision.surprisal, 2)} bits of surprise.`
                : 'The model’s probability for each move from this position.'
            }
            legend={[
              { label: 'Other moves', color: COLORS.muted, shape: 'square' },
              ...(playedHere ? [{ label: 'Move played', color: sideColor(decision.color), shape: 'square' }] : []),
            ]}
          >
            <PolicyChart rows={candidates} accent={sideColor(decision.color)} />
          </ChartCard>
        ) : (
          <Empty>{decision ? 'No legal moves — the game is over.' : 'Scoring the position…'}</Empty>
        )}
      </Section>

      {hasMoves && (
        <Section id="moves" title="Every move" meta={`${mine.length} by ${who === 'You' ? 'you' : who}`} defaultOpen={false}>
          <MovesTable rows={mine} current={current} onSeek={onSeek} />
        </Section>
      )}

      {hasMoves && (
        <Section id="calibration" title="Model fit" meta={fit ? `r² = ${fmt(fit.r2, 2)}` : undefined} defaultOpen={false}>
          {fit ? (
            <>
              <div className="metric-grid metric-grid-3">
                <Metric label="Fit r²" value={fmt(fit.r2, 2)} note={`over ${fit.n} positions`} />
                <Metric label="Slope" value={fmt(fit.slope, 2)} note="engine pawns per model pawn" />
                <Metric label="Typical miss" value={fmt(fit.rmse, 2)} unit=" pawns" note="root-mean-square" />
              </div>
              <ChartCard
                title="Model against engine"
                caption="Each dot is a position. The closer to the line, the more the simple model agrees with Stockfish."
              >
                <CalibrationChart pairs={pairs} />
              </ChartCard>
            </>
          ) : (
            <Empty>Appears once the engine has evaluated a few positions.</Empty>
          )}
        </Section>
      )}

      <footer className="metrics-foot">
        <button className="link-btn" onClick={onGuide}>
          What do these numbers mean? Read the guide →
        </button>
      </footer>
    </div>
  );
}
