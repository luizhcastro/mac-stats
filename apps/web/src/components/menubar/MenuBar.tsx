import type { LiveStats } from '../../hooks/useLiveStats'
import { MAIN_WINDOW_ID, REPO_URL } from '../../lib/links'
import type { BarMetric } from '../../lib/metrics'
import { AppleLogo } from '../Icon'
import { Clock } from './Clock'
import { MenuBarItem } from './MenuBarItem'

type StatusItemsProps = {
  stats: LiveStats
  visible: Set<BarMetric>
  onItemClick?: (metric: BarMetric) => void
  /** Registers each item's element so the dropdown can anchor under it */
  itemRef?: (metric: BarMetric) => (el: HTMLButtonElement | null) => void
}

type MenuBarProps = Required<StatusItemsProps>

/** Where the app menus would be: the page's own sections, like the menus of a frontmost app */
const MENUS = [
  { label: 'Window', href: `#${MAIN_WINDOW_ID}`, hide: 'max-sm:hidden' },
  { label: 'Features', href: '#features', hide: 'max-[480px]:hidden' },
  { label: 'Install', href: '#install', hide: 'max-[400px]:hidden' },
  { label: 'GitHub', href: REPO_URL, hide: 'max-lg:hidden' },
]

/** MB/s → integer-only "512K" / "3M", like `SingleMetricLabel.compactShort` */
function compactRate(mbPerSec: number): string {
  return mbPerSec >= 1 ? `${mbPerSec.toFixed(0)}M` : `${(mbPerSec * 1000).toFixed(0)}K`
}

export function MenuBar({ stats, visible, onItemClick, itemRef }: MenuBarProps) {
  return (
    <nav aria-label="Page" className="glass sticky top-0 z-30 flex h-[30px] items-center justify-between rounded-none border-x-0 border-t-0 px-3.5 text-[13px] max-sm:px-2.5">
      <div className="flex items-center gap-1 max-sm:gap-0">
        <span className="px-2">
          <AppleLogo />
        </span>
        <a href="#top" className="rounded-md px-2 py-0.5 font-bold hover:bg-white/18">
          MacStats
        </a>
        {MENUS.map(({ label, href, hide }) => (
          <a key={label} href={href} className={`rounded-md px-2 py-0.5 hover:bg-white/18 ${hide}`}>
            {label}
          </a>
        ))}
      </div>

      <StatusItems stats={stats} visible={visible} onItemClick={onItemClick} itemRef={itemRef} />
    </nav>
  )
}

/**
 * The MacStats status items plus the clock, the right half of the menu bar. Without
 * `onItemClick` it's a static crop (the feature and install fragments further down).
 */
export function StatusItems({ stats, visible, onItemClick, itemRef }: StatusItemsProps) {
  // Slot widths come from SingleMetricLabel.swift so the values don't jitter
  const items = [
    { id: 'cpu', label: 'CPU usage', icon: 'cpu', value: `${stats.cpu.total.toFixed(0)}%`, width: 30 },
    { id: 'temperature', label: 'CPU temperature', icon: 'thermometer', value: `${stats.temperature.cpu.toFixed(0)}°`, width: 26 },
    { id: 'ram', label: 'Memory in use', icon: 'memorychip', value: `${stats.memory.usedGB.toFixed(0)}G`, width: 32 },
    { id: 'disk', label: 'Disk activity', icon: 'internaldrive', value: compactRate(stats.disk.read + stats.disk.write), width: 36 },
    { id: 'network', label: 'Network rate', icon: 'network', value: compactRate(stats.network.in + stats.network.out), width: 36 },
  ] as const

  return (
    <div data-ui className="flex items-center gap-1.5 max-sm:gap-0.5" inert={!onItemClick}>
      {visible.has('appIcon') && (
        <MenuBarItem ref={itemRef?.('appIcon')} appIcon metric="appIcon" label="MacStats" onClick={() => onItemClick?.('appIcon')} />
      )}
      {items
        .filter((item) => visible.has(item.id))
        .map((item) => (
          <MenuBarItem key={item.id} ref={itemRef?.(item.id)} metric={item.id} {...item} onClick={() => onItemClick?.(item.id)} />
        ))}
      <Clock />
    </div>
  )
}
