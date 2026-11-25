import { useCallback, useState } from 'react';

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

export function Skeleton({ width = '100%', height = '1em', radius = 6 }) {
  return <span className="skeleton" style={{ width, height, borderRadius: radius }} aria-hidden="true" />;
}

/** Three dots that breathe while the computer thinks. */
export function Thinking({ label = 'Thinking' }) {
  return (
    <span className="thinking" role="status" aria-label={label}>
      <i />
      <i />
      <i />
    </span>
  );
}
