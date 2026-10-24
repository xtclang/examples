import { useMemo } from 'react';
import {
  barX,
  barY,
  defineChart,
  differenceY,
  dot,
  linearRegressionY,
  lineY,
  ruleX,
  ruleY,
  text,
} from '@tanstack/charts';
import { crosshair } from '@tanstack/charts/crosshair';
import { motion } from '@tanstack/charts/motion';
import { Chart } from '@tanstack/charts/react/core';
import { scaleBand } from '@tanstack/charts/scales/band';
import { scaleLinear } from '@tanstack/charts/scales/linear';
import { tooltip } from '@tanstack/charts/tooltip';
import { SEVERITY } from '../lib/insights.js';

// Every paint is a CSS variable, so the charts follow the light/dark toggle without being
// rebuilt. The two series hues follow the sides: gold for White (you, when playing), blue for
// Black (the engine). Validated per theme (adjacent CVD ΔE ≥ 23, normal-vision ΔE ≥ 24, ≥ 3:1
// against the surface); the values live in index.css.
export const COLORS = {
  white: 'var(--series-w)',
  black: 'var(--series-b)',
  ink: 'var(--ink)',
  ink2: 'var(--ink-2)',
  muted: 'var(--muted)',
  grid: 'var(--grid)',
  axis: 'var(--line)',
};

/** The series colour for a side: 'w' or 'b'. */
export const sideColor = (color) => (color === 'b' ? COLORS.black : COLORS.white);

const THEME = {
  foreground: COLORS.muted,
  muted: COLORS.muted,
  grid: COLORS.grid,
  background: 'transparent',
  palette: [COLORS.white, COLORS.black],
};

/**
 * Critically damped: settles without overshoot in about 0.35s. Stiffness and damping come from
 * that response time, k = (2π / 0.35)² and c = 2√k. Springs are interruptible -- a chart that
 * updates mid-animation carries its velocity into the new target instead of restarting -- which
 * is what live data needs. Reduced-motion users get the final frame.
 */
const SPRING = { type: 'spring', stiffness: 322, damping: 35.9, mass: 1 };

export const fmt = (n, d = 1) => (Number.isFinite(n) ? n.toFixed(d) : '—');
export const signed = (n, d = 1) => (Number.isFinite(n) ? `${n > 0 ? '+' : ''}${n.toFixed(d)}` : '—');
export const pct = (n, d = 0) => (Number.isFinite(n) ? `${(n * 100).toFixed(d)}%` : '—');

const moveOfPly = (ply) => Math.max(1, Math.ceil(ply / 2));

/** Ply positions for x-axis ticks: whole moves, spaced to about six labels. */
function moveTicks(lastPly) {
  const moves = Math.max(1, Math.floor(lastPly / 2));
  const step = Math.max(1, Math.ceil(moves / 6));
  const ticks = [];
  for (let m = step; m <= moves; m += step) ticks.push(m * 2);
  return ticks.length ? ticks : [Math.min(2, lastPly)];
}

/** Every chart goes through here: one spring renderer per chart, shared sizing and labelling. */
export function ChartView({ definition, height = 200, label, description, onSelect }) {
  const renderer = useMemo(() => motion({ transition: SPRING }), []);
  return (
    <Chart
      renderer={renderer}
      definition={definition}
      height={height}
      ariaLabel={label}
      ariaDescription={description}
      className="ts-chart"
      onSelect={onSelect}
    />
  );
}

const tip = (content) => ({ use: tooltip, className: 'chart-tip', content });

// ------------------------------------------------------------------------- evaluation

/**
 * The engine's evaluation across the game. Polarity is the story, so the fill is diverging --
 * blue where White stands better, red where Black does -- and the two lobes meet at the exact
 * crossing rather than at the nearest sample.
 */
export function EvalChart({ points, current, onSeek, height = 210 }) {
  const definition = useMemo(() => {
    const rows = points.map((p, ply) => ({ ply, pawns: p?.pawns ?? null }));
    const last = Math.max(1, rows.length - 1);
    const peak = rows.reduce((m, r) => (r.pawns === null ? m : Math.max(m, Math.abs(r.pawns))), 0);
    const span = Math.max(1.5, Math.min(12, Math.ceil(peak)));

    return defineChart({
      marks: [
        differenceY(rows, {
          x: 'ply',
          y1: 0,
          y2: 'pawns',
          positiveFill: COLORS.white,
          negativeFill: COLORS.black,
          fillOpacity: 0.2,
          stroke: COLORS.ink,
          strokeWidth: 1.75,
          comparisonStroke: COLORS.axis,
          comparisonStrokeWidth: 1,
        }),
        ruleX([Math.min(current, last)], { stroke: COLORS.ink, strokeOpacity: 0.35 }),
        crosshair({ x: true, y: false }),
      ],
      scales: {
        x: {
          scale: scaleLinear().domain([0, last]),
          // One tick per few full moves, on White's plies, so no move number appears twice.
          axis: { line: false, ticks: { size: 0, values: moveTicks(last), format: (v) => String(v / 2) } },
        },
        y: {
          scale: scaleLinear().domain([-span, span]),
          grid: true,
          axis: { line: false, ticks: { size: 0, count: 5, format: (v) => (v === 0 ? '0' : signed(v, span >= 4 ? 0 : 1)) } },
        },
      },
      theme: THEME,
      focus: 'group-x',
      maxFocusDistance: Number.POSITIVE_INFINITY,
      tooltip: tip((group) => {
        const line = group.find((p) => p.markId.endsWith(':primary')) ?? group[0];
        const pawns = line?.datum?.pawns;
        const ply = line?.datum?.ply ?? 0;
        return {
          title: ply === 0 ? 'Start' : `After move ${moveOfPly(ply)}${ply % 2 ? '' : '…'}`,
          rows: [
            {
              label: 'Evaluation',
              value: Number.isFinite(pawns) ? `${signed(pawns, 2)} pawns` : 'not evaluated yet',
              color: pawns < 0 ? COLORS.black : COLORS.white,
            },
          ],
        };
      }),
    });
  }, [points, current]);

  return (
    <ChartView
      definition={definition}
      height={height}
      label="Engine evaluation across the game"
      description="Pawns from White's point of view. Above zero White is better, below zero Black is."
      onSelect={(point) => Number.isInteger(point?.datum?.ply) && onSeek?.(point.datum.ply)}
    />
  );
}

// ------------------------------------------------------------------------- cost of each move

/**
 * Win chance thrown away by each move, with the three thresholds that name a bad one drawn as
 * reference lines -- labelled, so the meaning never rests on colour.
 */
export function WinLostChart({ rows, current, onSeek, height = 190 }) {
  const definition = useMemo(() => {
    const judged = rows.filter((r) => r.winLost !== null);
    const lastMove = Math.max(1, ...rows.map((r) => r.moveNo));
    const top = Math.max(36, Math.ceil((Math.max(0, ...judged.map((r) => r.winLost)) + 4) / 5) * 5);
    const thresholds = SEVERITY.map((s) => ({ value: s.min, label: s.label }));

    return defineChart({
      marks: [
        ruleY(thresholds, { y: 'value', stroke: COLORS.axis, strokeOpacity: 1 }),
        text(thresholds, {
          x: () => 0.5,
          y: 'value',
          text: 'label',
          anchor: 'start',
          dx: 4,
          dy: -5,
          fontSize: 10,
          fill: COLORS.muted,
        }),
        barY(judged, {
          x: 'moveNo',
          y: 'winLost',
          fill: (r) => (r.ply === current ? COLORS.ink : sideColor(r.color)),
          radius: 4,
          maxThickness: 8,
        }),
      ],
      scales: {
        x: {
          scale: scaleLinear().domain([0.5, lastMove + 0.5]),
          axis: { line: false, ticks: { size: 0, count: 6, format: (v) => (Number.isInteger(v) ? String(v) : '') } },
        },
        y: {
          scale: scaleLinear().domain([0, top]),
          grid: true,
          axis: { line: false, ticks: { size: 0, count: 4, format: (v) => `${v}%` } },
        },
      },
      theme: THEME,
      focus: 'nearest-x',
      tooltip: tip(([point]) => {
        const r = point?.datum;
        if (!r) return { rows: [] };
        return {
          title: r.label,
          rows: [
            { label: 'Win chance lost', value: `${fmt(r.winLost, 1)} pts`, color: sideColor(r.color) },
            { label: 'Pawns lost', value: fmt(r.pawnsLost, 2) },
            { label: 'Accuracy', value: `${fmt(r.accuracy, 0)}%` },
            ...(r.severity ? [{ label: 'Verdict', value: SEVERITY.find((s) => s.key === r.severity).label }] : []),
            ...(r.engineBest && !r.matched ? [{ label: 'Engine preferred', value: r.engineBest }] : []),
          ],
        };
      }),
    });
  }, [rows, current]);

  return (
    <ChartView
      definition={definition}
      height={height}
      label="Win chance lost on each move"
      description="Percentage points of winning chance each move gave away, with inaccuracy, mistake and blunder thresholds."
      onSelect={(point) => Number.isInteger(point?.datum?.ply) && onSeek?.(point.datum.ply)}
    />
  );
}

// ------------------------------------------------------------------------- surprise and entropy

/**
 * How open each choice was (entropy, the line) against how unexpected the move played was
 * (surprise, the bars). Both are bits, so they honestly share one axis.
 */
export function ThinkingChart({ rows, current, onSeek, height = 190 }) {
  const definition = useMemo(() => {
    const scored = rows.filter((r) => r.surprisal !== null);
    const lastMove = Math.max(1, ...rows.map((r) => r.moveNo));
    const top = Math.max(4, Math.ceil(Math.max(0, ...scored.map((r) => Math.max(r.surprisal, r.entropy)))));

    return defineChart({
      marks: [
        barY(scored, {
          id: 'surprise',
          x: 'moveNo',
          y: 'surprisal',
          fill: (r) => (r.ply === current ? COLORS.ink : sideColor(r.color)),
          radius: 4,
          maxThickness: 8,
        }),
        lineY(scored, { id: 'entropy', x: 'moveNo', y: 'entropy', stroke: COLORS.ink, strokeWidth: 1.75 }),
        crosshair({ x: true, y: false }),
      ],
      scales: {
        x: {
          scale: scaleLinear().domain([0.5, lastMove + 0.5]),
          axis: { line: false, ticks: { size: 0, count: 6, format: (v) => (Number.isInteger(v) ? String(v) : '') } },
        },
        y: {
          scale: scaleLinear().domain([0, top]),
          grid: true,
          axis: { line: false, ticks: { size: 0, count: 4, format: (v) => `${v} b` } },
        },
      },
      theme: THEME,
      focus: 'group-x',
      maxFocusDistance: Number.POSITIVE_INFINITY,
      tooltip: tip((group) => {
        const r = group[0]?.datum;
        if (!r) return { rows: [] };
        return {
          title: r.label,
          rows: [
            { label: 'Surprise', value: `${fmt(r.surprisal, 2)} bits`, color: sideColor(r.color) },
            { label: 'Entropy', value: `${fmt(r.entropy, 2)} bits`, color: COLORS.ink },
            { label: 'Model rank', value: r.rank ? `${r.rank} of ${r.branching}` : '—' },
            { label: 'Model probability', value: pct(r.pPlayed, 1) },
          ],
        };
      }),
    });
  }, [rows, current]);

  return (
    <ChartView
      definition={definition}
      height={height}
      label="Surprise and entropy of each decision"
      description="Bars: bits of surprise at the move played. Line: bits of uncertainty in the position."
      onSelect={(point) => Number.isInteger(point?.datum?.ply) && onSeek?.(point.datum.ply)}
    />
  );
}

// ------------------------------------------------------------------------- complexity

/** How many legal moves each side had to choose from, move by move: where the game got sharp. */
export function ComplexityChart({ decisions, height = 170 }) {
  const definition = useMemo(() => {
    const rows = decisions
      .map((d, ply) => (d ? { ply, moveNo: moveOfPly(ply + 1), side: d.color === 'w' ? 'White' : 'Black', options: d.branching } : null))
      .filter(Boolean);
    const last = Math.max(1, ...rows.map((r) => r.moveNo));

    return defineChart({
      marks: [
        lineY(rows, {
          x: 'moveNo',
          y: 'options',
          z: 'side',
          stroke: (r) => (r.side === 'White' ? COLORS.white : COLORS.black),
          strokeWidth: 1.75,
        }),
        crosshair({ x: true, y: false }),
      ],
      scales: {
        x: {
          scale: scaleLinear().domain([1, Math.max(2, last)]),
          axis: { line: false, ticks: { size: 0, count: 6, format: (v) => (Number.isInteger(v) ? String(v) : '') } },
        },
        y: { scale: scaleLinear, nice: true, grid: true, axis: { line: false, ticks: { size: 0, count: 4 } } },
      },
      theme: THEME,
      focus: 'group-x',
      maxFocusDistance: Number.POSITIVE_INFINITY,
      tooltip: tip((group) => ({
        title: `Move ${group[0]?.datum?.moveNo ?? ''}`,
        rows: group.map((p) => ({
          label: `${p.datum.side} to move`,
          value: `${p.datum.options} options`,
          color: p.datum.side === 'White' ? COLORS.white : COLORS.black,
        })),
      })),
    });
  }, [decisions]);

  return (
    <ChartView
      definition={definition}
      height={height}
      label="Legal moves available to each side across the game"
      description="Line per side: the number of legal moves at each of that side's turns."
    />
  );
}

// ------------------------------------------------------------------------- the choice now

/** The policy's probability for each candidate move, best first, with the move played marked. */
export function PolicyChart({ rows, height, accent = COLORS.white }) {
  const definition = useMemo(() => {
    const peak = Math.max(0.01, ...rows.map((r) => r.p));
    return defineChart({
      marks: [
        barX(rows, {
          id: 'track',
          y: 'san',
          x: () => peak * 1.22,
          fill: COLORS.axis,
          fillOpacity: 0.35,
          radius: 4,
          maxThickness: 8,
        }),
        barX(rows, {
          id: 'probability',
          y: 'san',
          x: 'p',
          fill: (r) => (r.played ? accent : COLORS.ink),
          radius: 4,
          maxThickness: 8,
        }),
        text(rows, {
          y: 'san',
          x: 'p',
          text: (r) => `${(r.p * 100).toFixed(1)}%`,
          anchor: 'start',
          dx: 6,
          fontSize: 11,
          fill: COLORS.ink2,
        }),
      ],
      scales: {
        x: { scale: scaleLinear().domain([0, peak * 1.22]), axis: false },
        y: { scale: () => scaleBand().padding(0.3), axis: { line: false, ticks: { size: 0 } } },
      },
      theme: THEME,
      focus: 'nearest-y',
      tooltip: tip(([point]) => {
        const r = point?.datum;
        if (!r) return { rows: [] };
        return {
          title: r.played ? `${r.san} · played` : r.san,
          rows: [
            { label: 'Probability', value: pct(r.p, 1), color: r.played ? accent : COLORS.muted },
            { label: 'Model value', value: `${signed(r.v, 2)} pawns` },
          ],
        };
      }),
    });
  }, [rows, accent]);

  return (
    <ChartView
      definition={definition}
      height={height ?? Math.max(150, rows.length * 26 + 24)}
      label="The model's probability for each candidate move"
      description="Horizontal bars, best first. The move actually played is marked."
    />
  );
}

// ------------------------------------------------------------------------- calibration

/** The local model's value against the engine's, position by position, with the fitted line. */
export function CalibrationChart({ pairs, height = 210 }) {
  const definition = useMemo(() => {
    const rows = pairs.map(([model, engine], i) => ({ i, model, engine }));
    const clamp = (v) => Math.max(-8, Math.min(8, v));
    const clamped = rows.map((r) => ({ ...r, model: clamp(r.model), engine: clamp(r.engine) }));
    return defineChart({
      marks: [
        ruleX([0], { stroke: COLORS.axis, strokeOpacity: 1 }),
        ruleY([0], { stroke: COLORS.axis, strokeOpacity: 1 }),
        linearRegressionY(clamped, {
          x: 'model',
          y: 'engine',
          stroke: COLORS.ink,
          strokeWidth: 1.5,
          fill: COLORS.ink,
          fillOpacity: 0.06,
        }),
        dot(clamped, { x: 'model', y: 'engine', r: 3.5, fill: COLORS.black, fillOpacity: 0.7 }),
      ],
      scales: {
        x: { scale: scaleLinear, nice: true, axis: { line: false, label: 'Model (pawns)', ticks: { size: 0, count: 5 } } },
        y: { scale: scaleLinear, nice: true, grid: true, axis: { line: false, label: 'Engine (pawns)', ticks: { size: 0, count: 5 } } },
      },
      theme: THEME,
      tooltip: tip(([point]) => ({
        title: 'Position',
        rows: [
          { label: 'Model', value: `${signed(point?.datum?.model, 2)} pawns`, color: COLORS.black },
          { label: 'Engine', value: `${signed(point?.datum?.engine, 2)} pawns` },
        ],
      })),
    });
  }, [pairs]);

  return (
    <ChartView
      definition={definition}
      height={height}
      label="Local model value against the engine evaluation"
      description="One dot per position; the line is the least-squares fit with its 95% band."
    />
  );
}
