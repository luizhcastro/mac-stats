import type { LiveStats } from '../../../hooks/useLiveStats'
import { ProgressBar } from '../../charts/ProgressBar'
import { MetricCard, Pane, PaneHeader, Secondary, Value, ValueLine } from '../PaneKit'

export function FansPane({ stats }: { stats: LiveStats }) {
  return (
    <Pane>
      <PaneHeader title="Fans" subtitle="Live SMC fan sensors" />
      {stats.fans.map((fan) => {
        const load = ((fan.rpm - fan.min) / (fan.max - fan.min)) * 100
        return (
          <MetricCard key={fan.name} title={fan.name} icon="fan">
            <ValueLine trailing={<Secondary>target {fan.target}</Secondary>}>
              <Value size={36}>{fan.rpm}</Value>
              <Secondary>RPM</Secondary>
            </ValueLine>
            <ProgressBar value={load} />
            <div className="flex justify-between text-xs text-secondary tabular-nums">
              <span>min {fan.min}</span>
              <span>max {fan.max}</span>
            </div>
          </MetricCard>
        )
      })}
    </Pane>
  )
}
