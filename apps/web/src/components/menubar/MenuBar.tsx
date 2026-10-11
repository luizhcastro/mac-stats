import type { LiveStats } from '../../hooks/useLiveStats'
import type { BarMetric } from '../../lib/metrics'
import { AppleLogo } from '../Icon'
import { Clock } from './Clock'
import { MenuBarItem } from './MenuBarItem'

type MenuBarProps = {
  stats: LiveStats
  visible: Set<BarMetric>
  onItemClick: (metric: BarMetric) => void
  /** Registers each item's element so the dropdown can anchor under it */
  itemRef: (metric: BarMetric) => (el: HTMLButtonElement | null) => void
}

export function MenuBar({ stats, visible, onItemClick, itemRef }: MenuBarProps) {
  // Slot widths come from SingleMetricLabel.swift so the values don't jitter
  const items = [
    { id: 'cpu', label: 'CPU usage', icon: 'cpu', value: `${stats.cpu.total.toFixed(0)}%`, width: 30 },
    { id: 'temperature', label: 'CPU temperature', icon: 'thermometer', value: `${stats.temperature.cpu.toFixed(0)}°`, width: 26 },
    { id: 'ram', label: 'Memory in use', icon: 'memorychip', value: `${stats.memory.usedGB.toFixed(1)}G`, width: 32 },
    { id: 'disk', label: 'Disk activity', icon: 'internaldrive', value: `${(stats.disk.read + stats.disk.write).toFixed(1)}M`, width: 36 },
    { id: 'network', label: 'Network rate', icon: 'network', value: `${stats.network.in.toFixed(1)}M`, width: 36 },
  ] as const

  return (
    <div className="glass sticky top-0 z-30 flex h-[30px] items-center justify-between rounded-none border-x-0 border-t-0 px-3.5 text-[13px] max-sm:px-2.5">
      <div className="flex items-center gap-[18px] max-sm:gap-3">
        <AppleLogo />
        <b className="max-[400px]:hidden">Finder</b>
        <span className="max-[480px]:hidden">File</span>
        <span className="max-[480px]:hidden">Edit</span>
        <span className="max-sm:hidden">View</span>
        <span className="max-desk:hidden">Go</span>
        <span className="max-desk:hidden">Window</span>
      </div>

      <div className="flex items-center gap-1.5 max-sm:gap-0.5">
        {visible.has('appIcon') && (
          <MenuBarItem ref={itemRef('appIcon')} appIcon metric="appIcon" label="MacStats" onClick={() => onItemClick('appIcon')} />
        )}
        {items
          .filter((item) => visible.has(item.id))
          .map((item) => (
            <MenuBarItem key={item.id} ref={itemRef(item.id)} metric={item.id} {...item} onClick={() => onItemClick(item.id)} />
          ))}
        <Clock />
      </div>
    </div>
  )
}
