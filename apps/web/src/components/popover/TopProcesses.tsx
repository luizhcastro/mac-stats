import type { Process } from '../../data/processes'
import { formatProcessValue, topProcesses } from '../../lib/format'
import { PROCESS_TABS, type ProcessTab } from '../../lib/metrics'

type TopProcessesProps = {
  tab: ProcessTab
  onTabChange: (tab: ProcessTab) => void
  processes: Process[]
}

/** Segmented picker + top 8 rows, mirrors TopProcessesView.swift */
export function TopProcesses({ tab, onTabChange, processes }: TopProcessesProps) {
  return (
    <section>
      <div role="tablist" className="grid grid-cols-5 rounded-lg bg-white/8">
        {PROCESS_TABS.map(({ id, label }, i) => {
          const selected = id === tab
          // Hairline between two unselected segments, like NSSegmentedControl
          const showSeparator = i > 0 && !selected && PROCESS_TABS[i - 1].id !== tab
          return (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={selected}
              onClick={() => onTabChange(id)}
              className={`relative cursor-pointer rounded-lg py-0.5 text-[13px] ${
                selected ? 'bg-accent font-medium text-on-accent shadow-[inset_0_0.5px_0_rgb(255_255_255/0.35)]' : ''
              }`}
            >
              {showSeparator && <span className="absolute top-1/4 left-0 h-1/2 border-l-[0.5px] border-white/20" />}
              {label}
            </button>
          )
        })}
      </div>

      <ul className="mt-1 text-[11px] leading-[1.32]">
        {topProcesses(processes, tab, 8).map((p) => (
          <li key={p.pid} className="flex justify-between gap-2 py-px">
            <span className="truncate">{p.name}</span>
            <span className="text-secondary tabular-nums">{formatProcessValue(tab, p)}</span>
          </li>
        ))}
      </ul>
    </section>
  )
}
