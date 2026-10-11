import { useState } from 'react'
import type { BarMetric } from '../../../lib/metrics'
import { MenuBarPrefs } from '../../popover/MenuBarPrefs'
import { MetricCard, Pane, PaneHeader } from '../PaneKit'

type SettingsPaneProps = {
  visible: Set<BarMetric>
  onToggleMetric: (metric: BarMetric) => void
}

/** SettingsPane.swift. The menu bar checkboxes drive the replica's menu bar at the top of the page. */
export function SettingsPane({ visible, onToggleMetric }: SettingsPaneProps) {
  const [showInDock, setShowInDock] = useState(false)

  return (
    <Pane>
      <PaneHeader title="Settings" subtitle="Menu bar and Dock" />

      <MetricCard title="Menu bar" icon="menubar">
        <MenuBarPrefs visible={visible} onToggle={onToggleMetric} />
        <p className="text-xs text-secondary">
          Pick which metrics show in the menu bar. "App icon" adds a plain MacStats icon you can click to open this
          dropdown, so you can keep the bar clean.
        </p>
      </MetricCard>

      <MetricCard title="Dock" icon="dock">
        <label className="flex cursor-pointer items-center gap-2 text-sm">
          <input type="checkbox" checked={showInDock} onChange={(e) => setShowInDock(e.target.checked)} className="size-3.5 accent-white" />
          Show MacStats in the Dock
        </label>
        <p className="text-xs text-secondary">Off by default: MacStats lives in the menu bar only.</p>
      </MetricCard>
    </Pane>
  )
}
