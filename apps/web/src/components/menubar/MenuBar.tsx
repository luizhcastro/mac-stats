import type { LiveStats } from '../../hooks/useLiveStats'
import type { BarMetric } from '../../lib/metrics'
import { order } from '../../lib/motion'
import { Clock } from './Clock'
import { MenuBarItem } from './MenuBarItem'

type StatusItemsProps = {
  stats: LiveStats
  visible: Set<BarMetric>
  onItemClick?: (metric: BarMetric) => void
  /** The item whose dropdown is open */
  active?: BarMetric
  /** The dropdown hasn't been clicked yet: the active item plays the load sequence's click */
  introClick?: boolean
  /** Registers each item's element so the dropdown can anchor under it */
  itemRef?: (metric: BarMetric) => (el: HTMLButtonElement | null) => void
}

type MenuBarProps = Required<Omit<StatusItemsProps, 'active' | 'introClick'>> & Pick<StatusItemsProps, 'active' | 'introClick'>

/** MB/s → integer-only "512K" / "3M", like `SingleMetricLabel.compactShort` */
function compactRate(mbPerSec: number): string {
  return mbPerSec >= 1 ? `${mbPerSec.toFixed(0)}M` : `${(mbPerSec * 1000).toFixed(0)}K`
}

/**
 * The right half of a menu bar across the top of the hero's stage, where the dropdown hangs
 * from. Its own box clips it, so on load it slides down out of the stage's top edge.
 */
export function MenuBar(props: MenuBarProps) {
  return (
    <div aria-label="Menu bar preview" className="relative overflow-hidden desk:absolute desk:top-4 desk:right-0 desk:w-[44vw] desk:rounded-tl-xl">
      <div className="bar-enter glass glass-dark flex h-[30px] items-center justify-end rounded-none border-x-0 border-t-0 px-3.5 text-[13px] max-sm:px-2.5">
        <StatusItems {...props} />
      </div>
    </div>
  )
}

/**
 * The MacStats status items plus the clock, the right half of the menu bar. Without
 * `onItemClick` it's a static crop (the feature and install fragments further down).
 */
export function StatusItems({ stats, visible, active, introClick, onItemClick, itemRef }: StatusItemsProps) {
  // Slot widths come from SingleMetricLabel.swift so the values don't jitter
  const items = [
    { id: 'cpu', label: 'CPU usage', icon: 'cpu', value: `${stats.cpu.total.toFixed(0)}%`, width: 30 },
    { id: 'temperature', label: 'CPU temperature', icon: 'thermometer', value: `${stats.temperature.cpu.toFixed(0)}°`, width: 26 },
    { id: 'ram', label: 'Memory in use', icon: 'memorychip', value: `${stats.memory.usedGB.toFixed(0)}G`, width: 32 },
    { id: 'disk', label: 'Disk activity', icon: 'internaldrive', value: compactRate(stats.disk.read + stats.disk.write), width: 36 },
    { id: 'network', label: 'Network rate', icon: 'network', value: compactRate(stats.network.in + stats.network.out), width: 36 },
  ] as const
  const shown = items.filter((item) => visible.has(item.id))
  // On first load the items fill in from the clock leftward, like macOS adding status items
  const count = shown.length + (visible.has('appIcon') ? 1 : 0)

  return (
    <div data-ui className="flex items-center gap-1.5 max-sm:gap-0.5" inert={!onItemClick}>
      {visible.has('appIcon') && (
        <MenuBarItem
          ref={itemRef?.('appIcon')}
          appIcon
          metric="appIcon"
          label="MacStats"
          active={active === 'appIcon'}
          introClick={introClick}
          style={order(count)}
          onClick={() => onItemClick?.('appIcon')}
        />
      )}
      {shown.map((item, i) => (
        <MenuBarItem
          key={item.id}
          ref={itemRef?.(item.id)}
          metric={item.id}
          {...item}
          active={active === item.id}
          introClick={introClick}
          style={order(shown.length - i)}
          onClick={() => onItemClick?.(item.id)}
        />
      ))}
      <Clock />
    </div>
  )
}
