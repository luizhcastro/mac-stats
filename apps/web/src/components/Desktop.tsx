import { useEffect, useRef, useState, type CSSProperties } from 'react'
import type { LiveStats } from '../hooks/useLiveStats'
import { usePopoverAnchor, type PopoverPosition } from '../hooks/usePopoverAnchor'
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
 * The first screen: the hero copy and a grey stage with a menu bar across its top, the MacStats
 * dropdown open under whichever menu bar item was clicked last.
 */
/** Centre of the anchored menu bar item, in the desktop stage's own coordinates (it spans the right 44vw, the bar its top 30px) */
function stageOrigin(position: PopoverPosition | null) {
  if (!position) return undefined
  return { '--stage-ox': `calc(${position.left + position.arrow}px - 56vw)`, '--stage-oy': '15px' } as CSSProperties
}

export function Desktop({ stats, mixer, visible }: DesktopProps) {
  const [anchor, setAnchor] = useState<BarMetric>('cpu')
  const [tab, setTab] = useState<ProcessTab>('cpu')
  const [open, setOpen] = useState(true)
  const [openCount, setOpenCount] = useState(0)

  const itemElements = useRef(new Map<BarMetric, HTMLButtonElement>())
  const registerItem = (metric: BarMetric) => (el: HTMLButtonElement | null) => {
    if (el) itemElements.current.set(metric, el)
    else itemElements.current.delete(metric)
  }

  // If the anchored item gets hidden, fall back to the first visible one
  const effectiveAnchor = visible.has(anchor) ? anchor : BAR_METRICS.find((m) => visible.has(m.id))!.id
  const position = usePopoverAnchor(() => itemElements.current.get(effectiveAnchor), [effectiveAnchor, visible])

  // Like StatusBarController: the open item's own button closes the dropdown, any other item
  // re-anchors it (and reopens from the new arrow). Narrow screens keep it in the page flow,
  // where closing would leave a hole in the layout, so there every tap only re-anchors it.
  function onItemClick(metric: BarMetric) {
    if (open && position && metric === effectiveAnchor) return setOpen(false)
    setAnchor(metric)
    setTab(TAB_FOR_METRIC[metric])
    setOpen(true)
    setOpenCount((n) => n + 1)
  }

  // Esc closes it, as it does a transient NSPopover
  useEffect(() => {
    if (!open || !position) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    addEventListener('keydown', onKey)
    return () => removeEventListener('keydown', onKey)
  }, [open, position])

  return (
    // On wide screens the dropdown floats (position: absolute) and takes no space in the flow, so
    // reserve its height (~890px from the top) to keep the next section from sliding under it.
    // With the header above, the screen it fills is 3.5rem short of the viewport.
    <div id="top" className="relative min-h-svh scroll-mt-14 desk:min-h-[clamp(60rem,calc(100svh-3.5rem),80rem)]">
      <div className="page">
        <Hero />
        {/* Narrow screens: the stage is a band under the copy, the menu bar across its top and the
            dropdown under that, all in the page flow. Wide screens: the wrappers drop out and the
            stage is a field down the right side, the bar on its top edge, the dropdown hanging from it. */}
        <div className="relative -mx-[clamp(1.25rem,4vw,3rem)] mt-14 pb-12 desk:contents">
          <div
            aria-hidden="true"
            className="shutter absolute inset-0 bg-stage desk:top-4 desk:left-auto desk:w-[44vw] desk:rounded-l-xl"
            // The grey spreads from the anchored item, in the bar along the stage's top edge
            style={stageOrigin(position)}
          />
          <MenuBar
            stats={stats}
            visible={visible}
            active={open ? effectiveAnchor : undefined}
            introClick={openCount === 0}
            onItemClick={onItemClick}
            itemRef={registerItem}
          />
          <div className="relative px-[clamp(1.25rem,4vw,3rem)] pt-12 desk:contents">
            <StatsPopover
              stats={stats}
              mixer={mixer}
              position={position}
              open={open}
              openCount={openCount}
              tab={tab}
              onTabChange={setTab}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
