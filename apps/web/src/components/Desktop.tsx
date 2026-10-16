import { useRef, useState } from 'react'
import type { LiveStats } from '../hooks/useLiveStats'
import { usePopoverAnchor } from '../hooks/usePopoverAnchor'
import { BAR_METRICS, TAB_FOR_METRIC, type BarMetric, type ProcessTab } from '../lib/metrics'
import type { Mixer } from '../lib/mixer'
import { Hero } from './Hero'
import { MenuBar } from './menubar/MenuBar'
import { StatsPopover } from './popover/StatsPopover'

type DesktopProps = {
  stats: LiveStats
  mixer: Mixer
  visible: Set<BarMetric>
}

/**
 * The first screen: the macOS menu bar (doubling as the page nav), the hero copy and the
 * MacStats dropdown open under whichever menu bar item was clicked last, on a jade stage.
 */
export function Desktop({ stats, mixer, visible }: DesktopProps) {
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
    // On wide screens the dropdown floats (position: absolute) and takes no space in the flow, so
    // reserve its height (~870px from the top) to keep the next section from sliding under it.
    <div id="top" className="relative min-h-svh desk:min-h-[max(100svh,60rem)]">
      <MenuBar stats={stats} visible={visible} onItemClick={openFrom} itemRef={registerItem} />
      {/* Wide screens: the stage is a flat field down the right side, the dropdown hangs onto it
          from the menu bar. Narrower: the stage wraps the dropdown in the page flow, under the copy. */}
      <div aria-hidden="true" className="shutter absolute top-[30px] right-0 bottom-0 hidden w-[44vw] rounded-tl-[160px] bg-stage desk:block" />
      <div className="page">
        <Hero />
        <div className="shutter -mx-[clamp(1.25rem,4vw,3rem)] mt-14 rounded-tl-[72px] bg-stage px-[clamp(1.25rem,4vw,3rem)] py-12 desk:contents">
          <StatsPopover
            stats={stats}
            mixer={mixer}
            position={position}
            anchor={effectiveAnchor}
            tab={tab}
            onTabChange={setTab}
          />
        </div>
      </div>
    </div>
  )
}
