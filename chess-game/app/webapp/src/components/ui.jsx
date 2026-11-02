import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';

/** State that survives a reload. Falls back to plain state where storage is unavailable. */
export function usePersistentState(key, initial) {
  const [value, setValue] = useState(() => {
    try {
      const stored = localStorage.getItem(key);
      return stored === null ? initial : JSON.parse(stored);
    } catch {
      return initial;
    }
  });
  const set = useCallback(
    (next) => {
      setValue((current) => {
        const resolved = typeof next === 'function' ? next(current) : next;
        try {
          localStorage.setItem(key, JSON.stringify(resolved));
        } catch {
          // Private window or storage blocked: the choice lasts for this visit only.
        }
        return resolved;
      });
    },
    [key]
  );
  return [value, set];
}

/**
 * A segmented control whose highlight slides to the chosen option. The pill moves by transform
 * and follows the option's measured width, so it lands exactly on the label at any font size.
 */
export function Segmented({ options, value, onChange, label, size = 'md' }) {
  const host = useRef(null);
  const buttons = useRef({});
  const [pill, setPill] = useState(null);

  const measure = useCallback(() => {
    const el = buttons.current[value];
    if (el) setPill({ x: el.offsetLeft, width: el.offsetWidth });
  }, [value]);

  useLayoutEffect(measure, [measure, options]);
  useEffect(() => {
    if (!host.current) return;
    const ro = new ResizeObserver(measure);
    ro.observe(host.current);
    return () => ro.disconnect();
  }, [measure]);

  return (
    <div className={`segmented segmented-${size}`} role="group" aria-label={label} ref={host}>
      {pill && (
        <span
          className="segmented-pill"
          aria-hidden="true"
          style={{ transform: `translateX(${pill.x}px)`, width: pill.width }}
        />
      )}
      {options.map((option) => (
        <button
          key={option.value}
          ref={(el) => (buttons.current[option.value] = el)}
          className={option.value === value ? 'on' : ''}
          aria-pressed={option.value === value}
          onClick={() => onChange(option.value)}
        >
          {option.icon}
          <span>{option.label}</span>
        </button>
      ))}
    </div>
  );
}

function Chevron() {
  return (
    <svg className="chevron" viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
      <path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/**
 * A section that folds away. The body collapses by animating its grid row from 1fr to 0fr: no
 * measured heights, no layout thrash, and a CSS transition, so opening and closing in quick
 * succession reverses smoothly instead of restarting. Whether it is open is remembered.
 */
export function Section({ id, title, meta, defaultOpen = true, actions, children }) {
  const [open, setOpen] = usePersistentState(`section:${id}`, defaultOpen);
  const bodyId = `section-${id}`;
  return (
    <section className="section" data-open={open}>
      <header className="section-head">
        <button
          className="section-toggle"
          aria-expanded={open}
          aria-controls={bodyId}
          onClick={() => setOpen((o) => !o)}
        >
          <Chevron />
          <h2>{title}</h2>
          {meta && <span className="section-meta">{meta}</span>}
        </button>
        {actions && <div className="section-actions">{actions}</div>}
      </header>
      <div id={bodyId} className="section-body" {...(open ? {} : { inert: '' })}>
        <div className="section-inner">{children}</div>
      </div>
    </section>
  );
}

export function Skeleton({ width = '100%', height = '1em', radius = 6 }) {
  return <span className="skeleton" style={{ width, height, borderRadius: radius }} aria-hidden="true" />;
}

/**
 * One number, on its own card. The value is keyed by its text, so a new value re-enters with a
 * brief blur-and-fade: a live update reads as an update, without anything sliding around.
 */
export function Metric({ label, value, unit, note, loading = false, emphasis = false, tone, index = 0 }) {
  return (
    <div className={emphasis ? 'metric metric-emphasis' : 'metric'} style={{ '--i': index }} data-tone={tone}>
      <span className="metric-label">{label}</span>
      {loading ? (
        <span className="metric-value">
          <Skeleton width="58%" height="1em" />
        </span>
      ) : (
        <span className="metric-value" key={`${value}${unit ?? ''}`}>
          {value}
          {unit && <span className="metric-unit">{unit}</span>}
        </span>
      )}
      {note && <span className="metric-note">{note}</span>}
    </div>
  );
}

export function Legend({ items }) {
  return (
    <ul className="legend">
      {items.map((item) => (
        <li key={item.label}>
          <span className={`key key-${item.shape ?? 'dot'}`} style={{ background: item.color }} aria-hidden="true" />
          {item.label}
        </li>
      ))}
    </ul>
  );
}

/** A chart on its own card: title, a sentence saying how to read it, legend, chart. */
export function ChartCard({ title, caption, legend, status, children, index = 0 }) {
  return (
    <article className="chart-card" style={{ '--i': index }}>
      <header className="chart-card-head">
        <h3>{title}</h3>
        {status}
      </header>
      {caption && <p className="chart-caption">{caption}</p>}
      {legend && <Legend items={legend} />}
      <div className="chart-slot">{children}</div>
    </article>
  );
}

/** A progress line for work that streams in. Linear motion: it is a constant process. */
export function Progress({ value, label }) {
  return (
    <div
      className="progress"
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(value * 100)}
    >
      <span style={{ transform: `scaleX(${Math.max(0, Math.min(1, value))})` }} />
    </div>
  );
}

/** Three dots that breathe while the engine thinks. */
export function Thinking({ label = 'Thinking' }) {
  return (
    <span className="thinking" role="status" aria-label={label}>
      <i />
      <i />
      <i />
    </span>
  );
}

export function Empty({ children }) {
  return <p className="empty">{children}</p>;
}

/**
 * A thin, fully rounded stacked bar with a row of counts beneath it: how the reference design
 * draws a split of outcomes. Segments keep their order; empty ones take no width.
 */
export function OutcomeBar({ segments, label }) {
  const total = segments.reduce((sum, s) => sum + (s.value || 0), 0);
  return (
    <div className="outcome">
      <div className="outcome-track" role="img" aria-label={label ?? segments.map((s) => `${s.label} ${s.value}`).join(', ')}>
        {total > 0 &&
          segments.map((s) =>
            s.value > 0 ? (
              <span
                key={s.label}
                className="outcome-seg"
                style={{ flexGrow: s.value, background: s.color }}
                title={`${s.label} ${s.value}`}
              />
            ) : null
          )}
      </div>
      <div className="outcome-legend">
        {segments.map((s) => (
          <span key={s.label}>
            {s.label} <b>{s.value}</b>
          </span>
        ))}
      </div>
    </div>
  );
}
