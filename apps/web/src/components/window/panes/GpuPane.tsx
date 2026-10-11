import { GPU_NAME } from '../../../data/system'
import type { LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS, temperatureColor } from '../../../lib/colors'
import { formatGB, formatPercent } from '../../../lib/format'
import { ProgressBar } from '../../charts/ProgressBar'
import { CardRow, MetricCard, Pane, PaneHeader, Value } from '../PaneKit'

/** Same thresholds as GPUPane.color(for:) */
function utilizationColor(util: number): string {
  if (util >= 80) return SYSTEM_COLORS.red
  if (util >= 50) return SYSTEM_COLORS.orange
  if (util >= 25) return SYSTEM_COLORS.yellow
  return SYSTEM_COLORS.green
}

export function GpuPane({ stats }: { stats: LiveStats }) {
  const { gpu, temperature } = stats

  return (
    <Pane>
      <PaneHeader title="GPU" subtitle={GPU_NAME} />

      <MetricCard title="Utilization" icon="display">
        <Value size={36} color={utilizationColor(gpu.utilization)}>
          {formatPercent(gpu.utilization)}
        </Value>
        <ProgressBar value={gpu.utilization} />
      </MetricCard>

      <CardRow>
        <MetricCard title="Renderer" icon="display">
          <Value size={22}>{formatPercent(gpu.renderer)}</Value>
        </MetricCard>
        <MetricCard title="Tiler" icon="grid">
          <Value size={22}>{formatPercent(gpu.tiler)}</Value>
        </MetricCard>
        <MetricCard title="Devices" icon="cpu">
          <Value size={22}>1</Value>
        </MetricCard>
      </CardRow>

      <MetricCard title="VRAM in use" icon="memorychip">
        <Value size={22}>{formatGB(gpu.vramGB)}</Value>
      </MetricCard>

      <MetricCard title="GPU Temperature" icon="thermometer">
        <Value size={22} color={temperatureColor(temperature.gpu)}>
          {temperature.gpu.toFixed(0)}°C
        </Value>
      </MetricCard>
    </Pane>
  )
}
