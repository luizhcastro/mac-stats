import type { LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS, temperatureColor } from '../../../lib/colors'
import { historyFor, niceMax, type HistoryRange } from '../../../lib/history'
import { AreaChart } from '../../charts/AreaChart'
import { CardRow, MetricCard, Pane, PaneHeader, RangePicker, Value, ValueLine } from '../PaneKit'

type TemperaturePaneProps = { stats: LiveStats; range: HistoryRange; onRangeChange: (range: HistoryRange) => void }

export function TemperaturePane({ stats, range, onRangeChange }: TemperaturePaneProps) {
  const { temperature } = stats
  const history = historyFor(stats, 'temperature', range)

  return (
    <Pane>
      <PaneHeader title="Temperature" subtitle="Live thermal sensors via IOHID" trailing={<RangePicker value={range} onChange={onRangeChange} />} />

      <MetricCard title="CPU" icon="cpu">
        <ValueLine trailing={<span className="text-nominal">Pressure: Nominal</span>}>
          <Value size={36} color={temperatureColor(temperature.cpu)}>
            {temperature.cpu.toFixed(0)}°C
          </Value>
        </ValueLine>
        <AreaChart series={[{ values: history, color: SYSTEM_COLORS.orange }]} max={niceMax(history, 80)} height={160} />
      </MetricCard>

      <CardRow>
        <MetricCard title="GPU" icon="display">
          <Value size={22} color={temperatureColor(temperature.gpu)}>
            {temperature.gpu.toFixed(0)}°C
          </Value>
        </MetricCard>
        <MetricCard title="Hottest sensor" icon="thermometer">
          <Value size={22} color={temperatureColor(temperature.max)}>
            {temperature.max.toFixed(0)}°C
          </Value>
        </MetricCard>
        <MetricCard title="Sensors" icon="gauge">
          <Value size={22}>{temperature.sensors}</Value>
        </MetricCard>
      </CardRow>
    </Pane>
  )
}
