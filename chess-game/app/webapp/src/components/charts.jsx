import { useEffect, useLayoutEffect, useRef, useState } from 'react';

// Shared geometry. Thin marks, recessive axes, white doing the separating.
const PAD = { l: 40, r: 16, t: 10, b: 22 };
const BAR_MAX = 24;
const BAR_GAP = 2;

export const fmt = (n, d = 1) => (Number.isFinite(n) ? n.toFixed(d) : '—');
export const signed = (n, d = 1) => (Number.isFinite(n) ? `${n > 0 ? '+' : ''}${n.toFixed(d)}` : '—');
export const pct = (n, d = 0) => (Number.isFinite(n) ? `${(n * 100).toFixed(d)}%` : '—');

/** Tracks the rendered width so the SVG can be drawn at real pixels, never stretched. */
function useWidth(ref, initial = 420) {
  const [width, setWidth] = useState(initial);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => setWidth(Math.max(240, el.clientWidth));
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, [ref]);
  return width;
}

/** Nearest-index hover, shared by every plotted chart. */
function useHover(count, width) {
  const [hover, setHover] = useState(null);
  useEffect(() => setHover(null), [count]);
  const plotW = width - PAD.l - PAD.r;
  const onMove = (e) => {
    if (count < 1) return;
    const box = e.currentTarget.getBoundingClientRect();
    const t = (e.clientX - box.left - PAD.l) / Math.max(plotW, 1);
    setHover(Math.min(count - 1, Math.max(0, Math.round(t * (count - 1)))));
  };
  return [hover, { onMouseMove: onMove, onMouseLeave: () => setHover(null) }];
}

// ----------------------------------------------------------------- chrome

export function Panel({ title, caption, legend, children, aside, table }) {
  return (
    <section className="panel">
      <header className="panel-head">
        <h3>{title}</h3>
        {aside}
      </header>
      {caption && <p className="caption">{caption}</p>}
      {legend && <Legend items={legend} />}
      {children}
      {table && <DataTable {...table} />}
    </section>
  );
}

export function Legend({ items }) {
  return (
    <ul className="legend">
      {items.map((item) => (
        <li key={item.label}>
          <span
            className={`key key-${item.shape ?? 'dot'}`}
            style={{ background: item.color }}
            aria-hidden="true"
          />
          {item.label}
        </li>
      ))}
    </ul>
  );
}

/** Every chart ships one, so no value is reachable only by colour or by hovering. */
export function DataTable({ columns, rows, label = 'Data table' }) {
  if (!rows?.length) return null;
  return (
    <details className="table-view">
      <summary>{label}</summary>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              {columns.map((c) => (
                <th key={c} scope="col">
                  {c}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={i}>
                {r.map((cell, j) => (
                  <td key={j}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </details>
  );
}

export function StatTile({ label, value, unit, note, hero = false }) {
  return (
    <div className={hero ? 'tile tile-hero' : 'tile'}>
      <span className="tile-label">{label}</span>
      <span className="tile-value">
        {value}
        {unit && <span className="tile-unit">{unit}</span>}
      </span>
      {note && <span className="tile-note">{note}</span>}
    </div>
  );
}

export function Progress({ value, label }) {
  return (
    <div className="progress" role="progressbar" aria-valuenow={Math.round(value * 100)}
         aria-valuemin={0} aria-valuemax={100} aria-label={label}>
      <span style={{ width: `${Math.min(100, value * 100)}%` }} />
    </div>
  );
}

export function Empty({ children }) {
  return <p className="empty">{children}</p>;
}

// --------------------------------------------------------- evaluation curve

/**
 * The engine's evaluation across the game. Polarity is the story, so the fill is diverging:
 * blue where White stands better, red where Black does, with a neutral zero line between.
 */
export function EvalCurve({ points, current, onSelect, height = 164 }) {
  const ref = useRef(null);
  const width = useWidth(ref);
  const [hover, bind] = useHover(points.length, width);

  const plotW = width - PAD.l - PAD.r;
  const plotH = height - PAD.t - PAD.b;
  const last = Math.max(points.length - 1, 1);
  const peak = points.reduce((m, p) => (p == null ? m : Math.max(m, Math.abs(p))), 0);
  const span = Math.max(1.5, Math.min(12, Math.ceil(peak)));

  const x = (i) => PAD.l + (i / last) * plotW;
  const y = (v) => PAD.t + plotH / 2 - (Math.max(-span, Math.min(span, v)) / span) * (plotH / 2);
  const zero = y(0);

  // Split at gaps so positions the engine could not answer leave a hole, not a straight line.
  const runs = [];
  let run = [];
  points.forEach((v, i) => {
    if (v == null) {
      if (run.length) runs.push(run);
      run = [];
    } else {
      run.push([x(i), y(v), i]);
    }
  });
  if (run.length) runs.push(run);

  const line = runs.map((r) => `M ${r.map(([px, py]) => `${px} ${py}`).join(' L ')}`).join(' ');
  const area = runs
    .map((r) => `M ${r[0][0]} ${zero} L ${r.map(([px, py]) => `${px} ${py}`).join(' L ')} L ${r.at(-1)[0]} ${zero} Z`)
    .join(' ');

  const extreme = points.reduce(
    (best, v, i) => (v != null && (best == null || Math.abs(v) > Math.abs(points[best])) ? i : best),
    null
  );
  const shown = hover ?? current;
  const value = points[shown];

  return (
    <div className="chart" ref={ref}>
      <svg width={width} height={height} {...bind}
           onClick={() => hover != null && onSelect?.(hover)} role="img"
           aria-label="Engine evaluation across the game, in pawns from White's point of view">
        <defs>
          <clipPath id="eval-up"><rect x={0} y={0} width={width} height={zero} /></clipPath>
          <clipPath id="eval-down"><rect x={0} y={zero} width={width} height={height - zero} /></clipPath>
        </defs>

        {[span, span / 2, -span / 2, -span].map((t) => (
          <line key={t} className="grid" x1={PAD.l} x2={width - PAD.r} y1={y(t)} y2={y(t)} />
        ))}
        {[span, span / 2, 0, -span / 2, -span].map((t) => (
          <text key={t} className="tick" x={PAD.l - 6} y={y(t) + 3} textAnchor="end">
            {t === 0 ? '0' : signed(t, span >= 4 ? 0 : 1)}
          </text>
        ))}
        <line className="axis" x1={PAD.l} x2={width - PAD.r} y1={zero} y2={zero} />

        <path className="area-up" d={area} clipPath="url(#eval-up)" />
        <path className="area-down" d={area} clipPath="url(#eval-down)" />
        <path className="line-up" d={line} clipPath="url(#eval-up)" />
        <path className="line-down" d={line} clipPath="url(#eval-down)" />

        {[...new Set([0, Math.round(last / 2), last])].map((i) => (
          <text key={i} className="tick" x={x(i)} y={height - 6} textAnchor="middle">
            {Math.floor(i / 2) + 1}
          </text>
        ))}

        {extreme != null && (
          <text className="point-label" x={x(extreme)}
                y={y(points[extreme]) + (points[extreme] > 0 ? -8 : 14)}
                textAnchor={labelAnchor(x(extreme), width)}>
            {signed(points[extreme])}
          </text>
        )}

        {value != null && (
          <>
            <line className="axis" x1={x(shown)} x2={x(shown)} y1={PAD.t} y2={PAD.t + plotH} />
            <circle className={value >= 0 ? 'dot-up' : 'dot-down'} cx={x(shown)} cy={y(value)} r={4} />
          </>
        )}
      </svg>
      {hover != null && points[hover] != null && (
        <Tip x={x(hover)} width={width}>
          <strong>move {Math.floor(hover / 2) + 1}</strong> · {signed(points[hover])} pawns
        </Tip>
      )}
    </div>
  );
}

// ------------------------------------------------------------ bars (+ line)

/**
 * One measure as columns, optionally a second in the same unit as a line over them.
 * Two scales on one plot is never right, so both series must share the unit.
 */
export function BarLineChart({
  rows, bar, line, height = 164, yMin = 2, onSelect, current, format = (n) => fmt(n),
}) {
  const ref = useRef(null);
  const width = useWidth(ref);
  const [hover, bind] = useHover(rows.length, width);

  const plotW = width - PAD.l - PAD.r;
  const plotH = height - PAD.t - PAD.b;
  const peak = rows.reduce(
    (m, r) => Math.max(m, bar ? r[bar.key] ?? 0 : 0, line ? r[line.key] ?? 0 : 0),
    0
  );
  const span = Math.max(yMin, Math.ceil(peak * 10) / 10);
  const band = plotW / Math.max(rows.length, 1);
  const barW = Math.max(1, Math.min(BAR_MAX, band - BAR_GAP));

  const x = (i) => PAD.l + band * (i + 0.5);
  const y = (v) => PAD.t + plotH - (Math.max(0, Math.min(span, v)) / span) * plotH;
  const base = PAD.t + plotH;

  // 4px rounded data-end, square at the baseline.
  const column = (i, v) => {
    const top = y(v);
    const h = base - top;
    const left = x(i) - barW / 2;
    const r = Math.min(4, barW / 2, h);
    if (h <= 0.5) return '';
    return `M ${left} ${base} L ${left} ${top + r} Q ${left} ${top} ${left + r} ${top} ` +
           `L ${left + barW - r} ${top} Q ${left + barW} ${top} ${left + barW} ${top + r} ` +
           `L ${left + barW} ${base} Z`;
  };

  const linePath = line
    ? `M ${rows.map((r, i) => `${x(i)} ${y(r[line.key] ?? 0)}`).join(' L ')}`
    : null;

  const extreme = bar
    ? rows.reduce((best, r, i) => ((r[bar.key] ?? 0) > (rows[best]?.[bar.key] ?? -1) ? i : best), 0)
    : null;

  return (
    <div className="chart" ref={ref}>
      <svg width={width} height={height} {...bind}
           onClick={() => hover != null && onSelect?.(rows[hover])} role="img"
           aria-label={bar?.label ?? line?.label}>
        {[span, span / 2].map((t) => (
          <line key={t} className="grid" x1={PAD.l} x2={width - PAD.r} y1={y(t)} y2={y(t)} />
        ))}
        {[span, span / 2, 0].map((t) => (
          <text key={t} className="tick" x={PAD.l - 6} y={y(t) + 3} textAnchor="end">
            {format(t)}
          </text>
        ))}

        {bar && rows.map((r, i) => (
          <path key={r.key ?? i} d={column(i, r[bar.key] ?? 0)}
                fill={current === r.key ? bar.activeColor ?? bar.color : bar.color}
                opacity={current != null && current !== r.key ? 0.55 : 1} />
        ))}
        {linePath && <path className="series-line" d={linePath} stroke={line.color} />}

        <line className="axis" x1={PAD.l} x2={width - PAD.r} y1={base} y2={base} />

        {rows.length > 0 && [0, Math.floor(rows.length / 2), rows.length - 1].map((i) => (
          <text key={i} className="tick" x={x(i)} y={height - 6} textAnchor="middle">
            {rows[i].moveNo}
          </text>
        ))}

        {bar && extreme != null && rows[extreme] && (rows[extreme][bar.key] ?? 0) > 0 && (
          <text className="point-label" x={x(extreme)} y={y(rows[extreme][bar.key]) - 6}
                textAnchor={labelAnchor(x(extreme), width)}>
            {format(rows[extreme][bar.key])}
          </text>
        )}
      </svg>
      {hover != null && rows[hover] && (
        <Tip x={x(hover)} width={width}>
          <strong>
            {rows[hover].moveNo}
            {rows[hover].san ? `. ${rows[hover].san}` : ''}
          </strong>
          {bar && <> · {bar.label}: {format(rows[hover][bar.key])}</>}
          {line && <> · {line.label}: {format(rows[hover][line.key])}</>}
        </Tip>
      )}
    </div>
  );
}

/** Keeps a direct label from running off either end of the plot. */
function labelAnchor(px, width) {
  if (px < PAD.l + 24) return 'start';
  if (px > width - PAD.r - 24) return 'end';
  return 'middle';
}

function Tip({ x, width, children }) {
  const clamped = Math.min(Math.max(x, 70), width - 70);
  return (
    <div className="tip" style={{ left: clamped }}>
      {children}
    </div>
  );
}

// -------------------------------------------------- candidate distribution

/**
 * The policy's probability over the moves available at one position. Built from HTML rather
 * than SVG so every bar carries its own readable label instead of relying on hue.
 */
export function CandidateBars({ rows, max }) {
  const scale = max ?? Math.max(...rows.map((r) => r.p), 0.0001);
  return (
    <ul className="candidates">
      <li className="cand-head" aria-hidden="true">
        <span className="cand-san">move</span>
        <span />
        <span className="cand-p">P</span>
        <span className="cand-v">V</span>
        <span />
      </li>
      {rows.map((r) => (
        <li key={r.san} className={r.played ? 'played' : ''}>
          <span className="cand-san">{r.san}</span>
          <span className="cand-track">
            <span className="cand-bar" style={{ width: `${Math.max(2, (r.p / scale) * 100)}%` }} />
          </span>
          <span className="cand-p">{pct(r.p, 1)}</span>
          <span className="cand-v">{signed(r.v)}</span>
          {r.played && <span className="tag">played</span>}
        </li>
      ))}
    </ul>
  );
}
