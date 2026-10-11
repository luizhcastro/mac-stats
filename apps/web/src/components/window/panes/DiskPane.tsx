import { VOLUMES, type Volume } from '../../../data/system'
import type { LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS } from '../../../lib/colors'
import { formatPercent, formatRate } from '../../../lib/format'
import { historyFor, niceMax, type HistoryRange } from '../../../lib/history'
import { AreaChart } from '../../charts/AreaChart'
import { ProgressBar } from '../../charts/ProgressBar'
import { Icon } from '../../Icon'
import { LabeledRate, LeaderList, MetricCard, Pane, PaneHeader, RangePicker, rangeLabel } from '../PaneKit'

type DiskPaneProps = { stats: LiveStats; range: HistoryRange; onRangeChange: (range: HistoryRange) => void }

export function DiskPane({ stats, range, onRangeChange }: DiskPaneProps) {
  const read = historyFor(stats, 'diskRead', range)
  const write = historyFor(stats, 'diskWrite', range)

  return (
    <Pane>
      <PaneHeader title="Disk" subtitle={`History range: ${rangeLabel(range)}`} trailing={<RangePicker value={range} onChange={onRangeChange} />} />

      <MetricCard title="Throughput" icon="internaldrive">
        <div className="flex gap-6">
          <LabeledRate label="Read" value={formatRate(stats.disk.read)} color={SYSTEM_COLORS.purple} />
          <LabeledRate label="Write" value={formatRate(stats.disk.write)} color={SYSTEM_COLORS.pink} />
        </div>
        <AreaChart
          filled={false}
          height={160}
          max={niceMax([...read, ...write], 0.256)}
          series={[
            { values: read, color: SYSTEM_COLORS.purple },
            { values: write, color: SYSTEM_COLORS.pink },
          ]}
        />
      </MetricCard>

      <MetricCard title={`Volumes (${VOLUMES.length})`} icon="internaldrive">
        <div className="divide-y divide-white/8">
          {VOLUMES.map((volume) => (
            <VolumeRow key={volume.bsdName} volume={volume} />
          ))}
        </div>
      </MetricCard>

      <MetricCard title="Top Disk Processes" icon="list">
        <LeaderList processes={stats.processes} tab="disk" />
      </MetricCard>
    </Pane>
  )
}

/** VolumeRow: name + BSD name + SMART badge, usage line, bar, mount path */
function VolumeRow({ volume }: { volume: Volume }) {
  const usage = (volume.usedGB / volume.totalGB) * 100
  const freeGB = volume.totalGB - volume.usedGB

  return (
    <div className="grid gap-1.5 py-3 first:pt-0 last:pb-0">
      <div className="flex items-baseline gap-2">
        <Icon name="internaldrive" className="size-3.5 self-center text-secondary" />
        <span className="text-sm font-medium">{volume.displayName}</span>
        <span className="text-xs text-tertiary tabular-nums">{volume.bsdName}</span>
        {volume.isReadOnly && <span className="rounded-full bg-white/12 px-1.5 text-[10px] text-secondary">read-only</span>}
        <SmartBadge status={volume.smart} />
      </div>
      <div className="flex items-baseline gap-2 tabular-nums">
        <span className="text-sm">
          {volume.usedGB.toFixed(1)} GB / {volume.totalGB.toFixed(1)} GB
        </span>
        <span className="text-xs text-secondary">· {freeGB.toFixed(1)} GB free</span>
        <span className="ml-auto text-xs text-secondary">{formatPercent(usage)}</span>
      </div>
      <ProgressBar value={usage} />
      <span className="truncate text-[10px] text-tertiary">{volume.mountPath}</span>
    </div>
  )
}

function SmartBadge({ status }: { status: Volume['smart'] }) {
  const healthy = status === 'healthy'
  return (
    <span
      className={`ml-auto rounded-full px-1.5 py-0.5 text-[10px] font-medium ${healthy ? 'bg-nominal/18 text-nominal' : 'bg-white/12 text-secondary'}`}
    >
      {healthy ? 'SMART OK' : 'SMART N/A'}
    </span>
  )
}
