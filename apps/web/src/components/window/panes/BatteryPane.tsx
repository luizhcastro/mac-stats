import { BATTERY } from '../../../data/battery'
import { SYSTEM_COLORS } from '../../../lib/colors'
import { formatPercent } from '../../../lib/format'
import { AreaChart } from '../../charts/AreaChart'
import { CenteredChart } from '../../charts/CenteredChart'
import { ProgressBar } from '../../charts/ProgressBar'
import { MetricCard, Pane, PaneHeader, StatRow, Value } from '../PaneKit'

export function BatteryPane() {
  const averageWatts = BATTERY.powerHistory.reduce((sum, w) => sum + w, 0) / BATTERY.powerHistory.length
  const powerCaption = `${averageWatts >= 0 ? 'Avg charge' : 'Avg drain'} ${Math.abs(averageWatts).toFixed(2)} W`

  return (
    <Pane>
      <PaneHeader title="Battery" subtitle={BATTERY.state} />

      <MetricCard title="Charge" icon="battery">
        <Value size={36}>{formatPercent(BATTERY.percent)}</Value>
        <ProgressBar value={BATTERY.percent} />
      </MetricCard>

      <MetricCard title="Charge History (last 30 min)" icon="gauge">
        <AreaChart
          series={[{ values: BATTERY.chargeHistory, color: BATTERY.isCharging ? SYSTEM_COLORS.green : SYSTEM_COLORS.blue }]}
          max={100}
          height={120}
        />
      </MetricCard>

      <MetricCard title="Power History (last 30 min)" icon="bolt">
        <CenteredChart values={BATTERY.powerHistory} color={SYSTEM_COLORS.orange} height={100} />
        <span className="text-xs text-secondary">{powerCaption}</span>
      </MetricCard>

      <MetricCard title="State" icon="bolt">
        <StatRow label="Charging" value={BATTERY.isCharging ? 'Yes' : 'No'} />
        <StatRow label="Plugged in" value={BATTERY.isPluggedIn ? 'Yes' : 'No'} />
        <StatRow label="Time remaining" value={BATTERY.timeRemaining} />
        <StatRow label="Power" value={`${BATTERY.watts.toFixed(2)} W`} />
      </MetricCard>

      <MetricCard title="Health" icon="heart">
        <StatRow label="Cycle count" value={String(BATTERY.cycles)} />
        <StatRow label="Maximum capacity" value={formatPercent(BATTERY.healthPercent)} />
        <StatRow label="Full charge" value={`${BATTERY.fullChargeMAh} mAh`} />
        <StatRow label="Design capacity" value={`${BATTERY.designCapacityMAh} mAh`} />
      </MetricCard>

      <MetricCard title="Cell" icon="bolt">
        <StatRow label="Voltage" value={`${BATTERY.voltage.toFixed(2)} V`} />
        <StatRow label="Current" value={`${BATTERY.amperageMA} mA`} />
        <StatRow label="Temperature" value={`${BATTERY.temperature.toFixed(1)}°C`} />
      </MetricCard>

      <MetricCard title="Hardware" icon="cpu">
        <StatRow label="Device" value={BATTERY.deviceName} />
        <StatRow label="Serial" value={BATTERY.serial} />
      </MetricCard>
    </Pane>
  )
}
