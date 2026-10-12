import type { Mixer } from '../../../lib/mixer'
import { MixerRows } from '../../popover/MixerRows'
import { MetricCard, Pane, PaneHeader } from '../PaneKit'

/** SoundPane in MixerView.swift */
export function SoundPane({ mixer }: { mixer: Mixer }) {
  return (
    <Pane>
      <PaneHeader title="Sound" subtitle="Per-app volume" />
      <MetricCard title="Apps" icon="speaker">
        <MixerRows mixer={mixer} />
        <p className="text-xs text-secondary">
          Volumes are saved per app and re-applied whenever it plays. Browsers mix every tab into one process, so a
          browser is one row.
        </p>
      </MetricCard>
    </Pane>
  )
}
