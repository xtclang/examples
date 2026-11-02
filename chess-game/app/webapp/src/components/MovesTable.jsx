import { useMemo, useState } from 'react';
import {
  createColumnHelper,
  createSortedRowModel,
  rowSortingFeature,
  sortFn_alphanumeric,
  sortFn_basic,
  tableFeatures,
  useTable,
} from '@tanstack/react-table';
import { SEVERITY } from '../lib/insights.js';
import { fmt, pct } from './charts.jsx';

const features = tableFeatures({
  rowSortingFeature,
  sortedRowModel: createSortedRowModel(),
  sortFns: { basic: sortFn_basic, alphanumeric: sortFn_alphanumeric },
});

const helper = createColumnHelper();

// Engine-dependent cells are undefined until evaluated, so they sort after the known values.
const known = (v) => (v === null || v === undefined || Number.isNaN(v) ? undefined : v);

const columns = helper.columns([
  helper.accessor('ply', {
    header: 'Move',
    sortFn: 'basic',
    cell: (info) => info.row.original.label,
  }),
  helper.accessor((r) => known(r.accuracy), {
    id: 'accuracy',
    header: 'Accuracy',
    sortFn: 'basic',
    sortUndefined: 'last',
    cell: (info) => (info.getValue() === undefined ? '…' : `${fmt(info.getValue(), 0)}%`),
  }),
  helper.accessor((r) => known(r.winLost), {
    id: 'winLost',
    header: 'Win lost',
    sortFn: 'basic',
    sortUndefined: 'last',
    cell: (info) => (info.getValue() === undefined ? '…' : `${fmt(info.getValue(), 1)}`),
  }),
  helper.accessor((r) => r.severity ?? '', {
    id: 'severity',
    header: 'Verdict',
    sortFn: 'alphanumeric',
    cell: (info) => {
      const s = SEVERITY.find((x) => x.key === info.getValue());
      return s ? <span className={`verdict verdict-${s.key}`}>{s.label}</span> : '';
    },
  }),
  helper.accessor((r) => r.engineBest ?? '', {
    id: 'engine',
    header: 'Engine',
    sortFn: 'alphanumeric',
    cell: (info) => {
      const r = info.row.original;
      if (!r.engineBest) return '…';
      return r.matched ? <span className="match">✓ same</span> : <code>{r.engineBest}</code>;
    },
  }),
  helper.accessor((r) => known(r.surprisal), {
    id: 'surprisal',
    header: 'Surprise',
    sortFn: 'basic',
    sortUndefined: 'last',
    cell: (info) => (info.getValue() === undefined ? '…' : `${fmt(info.getValue(), 2)} b`),
  }),
  helper.accessor((r) => known(r.pPlayed), {
    id: 'pPlayed',
    header: 'Model P',
    sortFn: 'basic',
    sortUndefined: 'last',
    cell: (info) => (info.getValue() === undefined ? '…' : pct(info.getValue(), 1)),
  }),
]);

/**
 * Every move of one side, sortable. Sorting by win chance lost is the quickest way to find the
 * moves worth studying; clicking a row puts that position on the board.
 */
export function MovesTable({ rows, current, onSeek }) {
  const [sorting, setSorting] = useState([{ id: 'ply', desc: false }]);
  const data = useMemo(() => rows, [rows]);

  const table = useTable({
    features,
    columns,
    data,
    state: { sorting },
    onSortingChange: setSorting,
  });

  return (
    <div className="moves-table-wrap">
      <div className="moves-table-title">Move history · {rows.length} {rows.length === 1 ? 'move' : 'moves'}</div>
      <table className="moves-table">
        <thead>
          {table.getHeaderGroups().map((group) => (
            <tr key={group.id}>
              {group.headers.map((header) => {
                const sorted = header.column.getIsSorted();
                return (
                  <th
                    key={header.id}
                    scope="col"
                    aria-sort={sorted === 'asc' ? 'ascending' : sorted === 'desc' ? 'descending' : 'none'}
                  >
                    <button className="th-sort" onClick={header.column.getToggleSortingHandler()}>
                      <table.FlexRender header={header} />
                      <span className="sort-mark" data-dir={sorted || undefined} aria-hidden="true" />
                    </button>
                  </th>
                );
              })}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row) => (
            <tr
              key={row.id}
              className={row.original.ply === current ? 'current' : undefined}
              onClick={() => onSeek?.(row.original.ply)}
            >
              {row.getAllCells().map((cell) => (
                <td key={cell.id}>
                  <table.FlexRender cell={cell} />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
