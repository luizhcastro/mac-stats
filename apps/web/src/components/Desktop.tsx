import { useRef, useState } from 'react'
import type { LiveStats } from '../hooks/useLiveStats'
import { usePopoverAnchor } from '../hooks/usePopoverAnchor'
import { BAR_METRICS, TAB_FOR_METRIC, type BarMetric, type ProcessTab } from '../lib/metrics'
import { Hero } from './Hero'
import { MenuBar } from './menubar/MenuBar'
import { StatsPopover } from './popover/StatsPopover'

type DesktopProps = {
  stats: LiveStats
  visible: Set<BarMetric>
  onToggleMetric: (metric: BarMetric) => void
}

/**
 * The first screen: a fake macOS desktop with the menu bar, the hero copy and the
 * MacStats dropdown open under whichever menu bar item was clicked last.
 */
export function Desktop({ stats, visible, onToggleMetric }: DesktopProps) {
  const [anchor, setAnchor] = useState<BarMetric>('cpu')
  const [tab, setTab] = useState<ProcessTab>('cpu')

  const itemElements = useRef(new Map<BarMetric, HTMLButtonElement>())
  const registerItem = (metric: BarMetric) => (el: HTMLButtonElement | null) => {
    if (el) itemElements.current.set(metric, el)
    else itemElements.current.delete(metric)
  }

  // If the anchored item gets hidden, fall back to the first visible one
  const effectiveAnchor = visible.has(anchor) ? anchor : BAR_METRICS.find((m) => visible.has(m.id))!.id
  const position = usePopoverAnchor(() => itemElements.current.get(effectiveAnchor), [effectiveAnchor, visible])

  function openFrom(metric: BarMetric) {
    setAnchor(metric)
    setTab(TAB_FOR_METRIC[metric])
  }

  return (
    // The dropdown floats (position: absolute), so it takes no space in the flow. Reserve at least
    // its height (~870px from the top) so the window section below never slides under it.
    <div className="relative min-h-[max(100svh,60rem)] pb-20">
      <MenuBar stats={stats} visible={visible} onItemClick={openFrom} itemRef={registerItem} />
      <div className="mx-auto max-w-[1280px] px-[clamp(1.25rem,4vw,3rem)]">
        <Hero />
        <StatsPopover
          stats={stats}
          position={position}
          tab={tab}
          onTabChange={setTab}
          visible={visible}
          onToggleMetric={onToggleMetric}
        />
      </div>
    </div>
  )
}
