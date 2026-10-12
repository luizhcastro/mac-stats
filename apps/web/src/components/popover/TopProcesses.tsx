import type { Process } from '../../data/processes'
import { useFlip } from '../../hooks/useFlip'
import { formatProcessValue, topProcesses } from '../../lib/format'
import { PROCESS_TABS, type ProcessTab } from '../../lib/metrics'
import { Segmented } from '../ui/Segmented'

type TopProcessesProps = {
  tab: ProcessTab
  onTabChange: (tab: ProcessTab) => void
  processes: Process[]
}

/**
 * Sliding segmented picker + top 8 rows, mirrors TopProcessesView.swift. Rows are keyed by
 * PID: a tab switch or re-rank slides a process to its new place, newcomers fade in.
 */
export function TopProcesses({ tab, onTabChange, processes }: TopProcessesProps) {
  const rows = topProcesses(processes, tab, 8)
  const listRef = useFlip<HTMLUListElement>([rows.map((p) => p.pid).join()])

  return (
    <div>
      <Segmented options={PROCESS_TABS} value={tab} onChange={onTabChange} className="text-[13px]" />
      <ul ref={listRef} className="relative mt-1 text-[11px] leading-[1.32]">
        {rows.map((p) => (
          <li key={p.pid} data-flip-key={p.pid} className="flex animate-reveal justify-between gap-2 py-px">
            <span className="truncate">{p.name}</span>
            <span className="text-secondary tabular-nums">{formatProcessValue(tab, p)}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
