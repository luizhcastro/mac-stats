import type { LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS } from '../../../lib/colors'
import { formatGB, formatPercent, formatRate } from '../../../lib/format'
import { historyFor, type HistoryRange } from '../../../lib/history'
import { AreaChart } from '../../charts/AreaChart'
import { ProgressBar } from '../../charts/ProgressBar'
import { CardRow, LeaderList, MetricCard, Pane, PaneHeader, RangePicker, Secondary, Value, ValueLine, rangeLabel } from '../PaneKit'

type MemoryPaneProps = { stats: LiveStats; range: HistoryRange; onRangeChange: (range: HistoryRange) => void }

export function MemoryPane({ stats, range, onRangeChange }: MemoryPaneProps) {
  const { memory } = stats

  return (
    <Pane>
      <PaneHeader title="Memory" subtitle={`History range: ${rangeLabel(range)}`} trailing={<RangePicker value={range} onChange={onRangeChange} />} />

      <MetricCard title="Used" icon="memorychip">
        <ValueLine>
          <Value size={36}>{formatGB(memory.usedGB)}</Value>
          <Secondary>of {formatGB(memory.totalGB)}</Secondary>
        </ValueLine>
        <AreaChart series={[{ values: historyFor(stats, 'memory', range), color: SYSTEM_COLORS.green }]} max={100} height={160} />
      </MetricCard>

      <CardRow>
        <MetricCard title="Active" icon="bolt">
          <Value size={20}>{formatGB(memory.activeGB)}</Value>
        </MetricCard>
        <MetricCard title="Wired" icon="memorychip">
          <Value size={20}>{formatGB(memory.wiredGB)}</Value>
        </MetricCard>
        <MetricCard title="Compressed" icon="grid">
          <Value size={20}>{formatGB(memory.compressedGB)}</Value>
        </MetricCard>
        <MetricCard title="Free" icon="gauge">
          <Value size={20}>{formatGB(memory.freeGB)}</Value>
        </MetricCard>
      </CardRow>

      <MetricCard title="Pressure" icon="gauge">
        <Value size={22}>{formatPercent(memory.pressure)}</Value>
        <ProgressBar value={memory.pressure} />
      </MetricCard>

      <MetricCard title="Swap" icon="memorychip">
        <ValueLine>
          <Value size={22}>{formatGB(memory.swapUsedGB)}</Value>
          <Secondary>of {formatGB(memory.swapTotalGB)}</Secondary>
        </ValueLine>
        <ProgressBar value={(memory.swapUsedGB / memory.swapTotalGB) * 100} />
        <div className="flex gap-6">
          {['Swap in', 'Swap out'].map((label) => (
            <div key={label} className="grid gap-0.5">
              <span className="text-xs text-secondary">{label}</span>
              <span className="text-sm tabular-nums">{formatRate(0)}</span>
            </div>
          ))}
        </div>
      </MetricCard>

      <MetricCard title="Top Memory Processes" icon="list">
        <LeaderList processes={stats.processes} tab="ram" />
      </MetricCard>
    </Pane>
  )
}
