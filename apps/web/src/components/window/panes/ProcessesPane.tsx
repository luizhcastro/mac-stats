import { useState } from 'react'
import type { Process } from '../../../data/processes'
import type { LiveStats } from '../../../hooks/useLiveStats'
import { formatCompactRate, formatGB, formatPercent } from '../../../lib/format'
import { Icon } from '../../Icon'
import { PaneHeader } from '../PaneKit'

type SortKey = 'name' | 'pid' | 'cpu' | 'memoryGB' | 'diskRead' | 'diskWrite' | 'netIn' | 'netOut'

/** Columns and widths from ProcessesPane.swift (Name flexes, the rest are fixed) */
const COLUMNS: { key: Exclude<SortKey, 'name'>; label: string; width: string; format: (p: Process) => string }[] = [
  { key: 'pid', label: 'PID', width: 'w-[70px]', format: (p) => String(p.pid) },
  { key: 'cpu', label: 'CPU', width: 'w-[70px]', format: (p) => formatPercent(p.cpu, 2) },
  { key: 'memoryGB', label: 'Memory', width: 'w-[100px]', format: (p) => formatGB(p.memoryGB) },
  { key: 'diskRead', label: 'Disk R', width: 'w-[90px]', format: (p) => formatCompactRate(p.diskRead) },
  { key: 'diskWrite', label: 'Disk W', width: 'w-[90px]', format: (p) => formatCompactRate(p.diskWrite) },
  { key: 'netIn', label: 'Net In', width: 'w-[90px]', format: (p) => formatCompactRate(p.netIn) },
  { key: 'netOut', label: 'Net Out', width: 'w-[90px]', format: (p) => formatCompactRate(p.netOut) },
]

/** Filterable, sortable table of every process, like ProcessesPane.swift */
export function ProcessesPane({ stats }: { stats: LiveStats }) {
  const [query, setQuery] = useState('')
  const [sortKey, setSortKey] = useState<SortKey>('cpu')
  const [ascending, setAscending] = useState(false)
  const [selectedPid, setSelectedPid] = useState<number | null>(null)

  // Clicking the active column flips the direction; a new column starts descending
  function sortBy(key: SortKey) {
    if (key === sortKey) setAscending(!ascending)
    else {
      setSortKey(key)
      setAscending(false)
    }
  }

  // The app's filter matches the name or the PID
  const q = query.trim().toLowerCase()
  const rows = stats.processes
    .filter((p) => !q || p.name.toLowerCase().includes(q) || String(p.pid).includes(q))
    .sort((a, b) => {
      const order = sortKey === 'name' ? a.name.localeCompare(b.name) : a[sortKey] - b[sortKey]
      return ascending ? order : -order
    })

  const total = stats.processes.length
  const selected = rows.find((p) => p.pid === selectedPid)

  return (
    <div className="flex h-full flex-col">
      <div className="px-6 pt-6">
        <PaneHeader
          title="Processes"
          subtitle={q ? `${rows.length} of ${total} match` : `${total} running`}
          trailing={
            <div className="flex items-center gap-3">
              <label className="flex items-center gap-1.5 rounded-lg bg-white/8 px-2 py-[5px] text-[13px]">
                <Icon name="search" className="size-3.5 text-secondary" />
                <input
                  type="search"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Filter…"
                  aria-label="Filter processes"
                  className="w-[180px] bg-transparent outline-none placeholder:text-tertiary max-sm:w-28"
                />
              </label>
              {selected && (
                <span className="flex items-center gap-1 text-[13px]" title="Send SIGTERM">
                  <Icon name="xmarkCircle" className="size-3.5" />
                  Quit
                </span>
              )}
            </div>
          }
        />
      </div>

      <div className="min-h-0 flex-1 overflow-auto">
        <div className="min-w-[680px]">
          <div className="sticky top-0 flex border-b border-separator bg-black/30 px-6 py-1.5 text-[11px] font-medium text-secondary backdrop-blur">
            <SortHeader label="Name" sortKey="name" current={sortKey} ascending={ascending} onSort={sortBy} className="flex-1 text-left" />
            {COLUMNS.map((column) => (
              <SortHeader
                key={column.key}
                label={column.label}
                sortKey={column.key}
                current={sortKey}
                ascending={ascending}
                onSort={sortBy}
                className={`${column.width} justify-end`}
              />
            ))}
          </div>

          {rows.map((p) => (
            <div
              key={p.pid}
              onClick={() => setSelectedPid(p.pid)}
              className={`flex h-[26px] cursor-default items-center px-6 text-xs tabular-nums ${
                p.pid === selectedPid ? 'bg-white/18' : ''
              }`}
            >
              <span className="flex-1 truncate">{p.name}</span>
              {COLUMNS.map((column) => (
                <span key={column.key} className={`${column.width} text-right`}>
                  {column.format(p)}
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

type SortHeaderProps = {
  label: string
  sortKey: SortKey
  current: SortKey
  ascending: boolean
  onSort: (key: SortKey) => void
  className: string
}

function SortHeader({ label, sortKey, current, ascending, onSort, className }: SortHeaderProps) {
  const active = sortKey === current
  return (
    <button
      type="button"
      onClick={() => onSort(sortKey)}
      aria-sort={active ? (ascending ? 'ascending' : 'descending') : undefined}
      className={`flex cursor-pointer items-center gap-1 ${className}`}
    >
      {label}
      {active && <span className="text-[9px] font-bold">{ascending ? '⌃' : '⌄'}</span>}
    </button>
  )
}
