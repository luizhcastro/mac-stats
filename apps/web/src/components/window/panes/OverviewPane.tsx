import { BATTERY } from '../../../data/battery'
import type { LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS, temperatureColor } from '../../../lib/colors'
import { formatGB, formatPercent, formatRate } from '../../../lib/format'
import { niceMax } from '../../../lib/history'
import { AreaChart } from '../../charts/AreaChart'
import { ProgressBar } from '../../charts/ProgressBar'
import { CardGrid, MetricCard, Pane, PaneHeader, RateLabel, Secondary, Value, ValueLine } from '../PaneKit'

/** DashboardPane.swift: one card per domain with the last minute charted */
export function OverviewPane({ stats }: { stats: LiveStats }) {
  const { cpu, memory, network, disk, temperature, history } = stats

  return (
    <Pane>
      <PaneHeader title="Overview" subtitle="Live snapshot of system activity" />
      <CardGrid>
        <MetricCard title="CPU" icon="cpu">
          <ValueLine trailing={<Secondary>user {formatPercent(cpu.user)} · sys {formatPercent(cpu.system)}</Secondary>}>
            <Value size={28}>{formatPercent(cpu.total)}</Value>
          </ValueLine>
          <AreaChart series={[{ values: history.cpu, color: SYSTEM_COLORS.blue }]} max={100} />
        </MetricCard>

        <MetricCard title="Memory" icon="memorychip">
          <ValueLine trailing={<Secondary>pressure {formatPercent(memory.pressure)}</Secondary>}>
            <Value size={28}>{formatGB(memory.usedGB)}</Value>
            <Secondary>/ {formatGB(memory.totalGB)}</Secondary>
          </ValueLine>
          <AreaChart series={[{ values: history.memory, color: SYSTEM_COLORS.green }]} max={100} />
        </MetricCard>

        <MetricCard title="Network" icon="network">
          <div className="flex flex-wrap gap-x-[18px] gap-y-1">
            <RateLabel direction="down" color={SYSTEM_COLORS.blue} value={formatRate(network.in)} />
            <RateLabel direction="up" color={SYSTEM_COLORS.orange} value={formatRate(network.out)} />
          </div>
          <AreaChart
            filled={false}
            max={niceMax([...history.netIn, ...history.netOut], 0.064)}
            series={[
              { values: history.netIn, color: SYSTEM_COLORS.blue },
              { values: history.netOut, color: SYSTEM_COLORS.orange },
            ]}
          />
        </MetricCard>

        <MetricCard title="Disk" icon="internaldrive">
          <div className="flex flex-wrap gap-x-[18px] gap-y-1">
            <RateLabel direction="down" color={SYSTEM_COLORS.purple} value={formatRate(disk.read)} />
            <RateLabel direction="up" color={SYSTEM_COLORS.pink} value={formatRate(disk.write)} />
          </div>
          <AreaChart
            filled={false}
            max={niceMax([...history.diskRead, ...history.diskWrite], 0.256)}
            series={[
              { values: history.diskRead, color: SYSTEM_COLORS.purple },
              { values: history.diskWrite, color: SYSTEM_COLORS.pink },
            ]}
          />
        </MetricCard>

        <MetricCard title="Battery" icon="battery">
          <ValueLine trailing={<Secondary>{BATTERY.timeRemaining} remaining</Secondary>}>
            <Value size={28}>{formatPercent(BATTERY.percent)}</Value>
          </ValueLine>
          <ProgressBar value={BATTERY.percent} />
        </MetricCard>

        <MetricCard title="Temperature" icon="thermometer">
          <ValueLine trailing={<Secondary>Nominal</Secondary>}>
            <Value size={28} color={temperatureColor(temperature.cpu)}>
              {temperature.cpu.toFixed(0)}°C
            </Value>
          </ValueLine>
          <AreaChart series={[{ values: history.temperature, color: SYSTEM_COLORS.orange }]} max={niceMax(history.temperature, 80)} />
        </MetricCard>
      </CardGrid>
    </Pane>
  )
}
