import { EFFICIENCY_CORES, PERFORMANCE_CORES, type LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS } from '../../../lib/colors'
import { formatPercent } from '../../../lib/format'
import { historyFor, type HistoryRange } from '../../../lib/history'
import { AreaChart } from '../../charts/AreaChart'
import { CardRow, LeaderList, MetricCard, Pane, PaneHeader, RangePicker, Value, rangeLabel } from '../PaneKit'

type CpuPaneProps = { stats: LiveStats; range: HistoryRange; onRangeChange: (range: HistoryRange) => void }

export function CpuPane({ stats, range, onRangeChange }: CpuPaneProps) {
  const { cpu } = stats

  return (
    <Pane>
      <PaneHeader title="CPU" subtitle={`History range: ${rangeLabel(range)}`} trailing={<RangePicker value={range} onChange={onRangeChange} />} />

      <MetricCard title="Total Usage" icon="cpu">
        <Value size={36}>{formatPercent(cpu.total)}</Value>
        <AreaChart series={[{ values: historyFor(stats, 'cpu', range), color: SYSTEM_COLORS.blue }]} max={100} height={160} />
      </MetricCard>

      <MetricCard title="Per-core Usage" icon="grid">
        <CoreBars usage={cpu.perCore} />
        <div className="flex gap-3 pt-1 text-xs text-secondary">
          <LegendDot color={SYSTEM_COLORS.blue} label={`P-cores (${PERFORMANCE_CORES})`} />
          <LegendDot color={SYSTEM_COLORS.green} label={`E-cores (${EFFICIENCY_CORES})`} />
        </div>
      </MetricCard>

      <MetricCard title="Load Average" icon="gauge">
        <div className="flex gap-7">
          {(['1 min', '5 min', '15 min'] as const).map((label, i) => (
            <div key={label} className="grid gap-0.5">
              <span className="text-xs text-secondary">{label}</span>
              <Value size={22}>{cpu.load[i].toFixed(2)}</Value>
            </div>
          ))}
        </div>
      </MetricCard>

      <CardRow>
        <MetricCard title="User" icon="cpu">
          <Value size={24}>{formatPercent(cpu.user)}</Value>
        </MetricCard>
        <MetricCard title="System" icon="gear">
          <Value size={24}>{formatPercent(cpu.system)}</Value>
        </MetricCard>
        <MetricCard title="Idle" icon="gauge">
          <Value size={24}>{formatPercent(100 - cpu.total)}</Value>
        </MetricCard>
      </CardRow>

      <MetricCard title="Top CPU Processes" icon="list">
        <LeaderList processes={stats.processes} tab="cpu" />
      </MetricCard>
    </Pane>
  )
}

/** CoreBars: a tinted track per core with the usage filled from the bottom, 90pt tall */
function CoreBars({ usage }: { usage: number[] }) {
  return (
    <div className="flex items-end gap-1">
      {usage.map((value, i) => {
        const color = i < PERFORMANCE_CORES ? SYSTEM_COLORS.blue : SYSTEM_COLORS.green
        return (
          <div key={i} className="grid flex-1 justify-items-center gap-1">
            <div className="relative h-[90px] w-full overflow-hidden rounded-[3px]" style={{ background: `${color}26` }}>
              <div
                className="absolute inset-x-0 bottom-0 rounded-[3px] transition-[height] duration-600 motion-reduce:transition-none"
                style={{ height: `max(2px, ${value}%)`, background: color }}
              />
            </div>
            <span className="text-[9px] font-medium text-secondary tabular-nums">{i}</span>
          </div>
        )
      })}
    </div>
  )
}

function LegendDot({ color, label }: { color: string; label: string }) {
  return (
    <span className="flex items-center gap-1">
      <span className="size-[7px] rounded-full" style={{ background: color }} />
      {label}
    </span>
  )
}
