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
 * The first screen: the macOS menu bar (doubling as the page nav), the hero copy and the
 * MacStats dropdown open under whichever menu bar item was clicked last, on a grey stage.
 */
/** Centre of the anchored menu bar item, in the desktop stage's own coordinates (it spans the right 44vw) */
function stageOrigin(position: PopoverPosition | null) {
  if (!position) return undefined
  return { '--stage-ox': `calc(${position.left + position.arrow}px - 56vw)`, '--stage-oy': '-15px' } as CSSProperties
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
  // below the copy: there a tap scrolls down to it (closing would leave a hole in the layout).
  const flowStage = useRef<HTMLDivElement>(null)
  function onItemClick(metric: BarMetric) {
    if (open && position && metric === effectiveAnchor) return setOpen(false)
    setAnchor(metric)
    setTab(TAB_FOR_METRIC[metric])
    setOpen(true)
    setOpenCount((n) => n + 1)
    if (!position) flowStage.current?.scrollIntoView({ block: 'start' })
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
    // reserve its height (~870px from the top) to keep the next section from sliding under it.
    <div id="top" className="relative min-h-svh desk:min-h-[max(100svh,60rem)]">
      <MenuBar
        stats={stats}
        visible={visible}
        active={open ? effectiveAnchor : undefined}
        introClick={openCount === 0}
        onItemClick={onItemClick}
        itemRef={registerItem}
      />
      {/* Wide screens: the stage is a flat field down the right side, the dropdown hangs onto it
          from the menu bar. Narrower: the stage wraps the dropdown in the page flow, under the copy. */}
      <div
        aria-hidden="true"
        className="shutter absolute top-[30px] right-0 bottom-0 hidden w-[44vw] rounded-tl-[160px] bg-stage desk:block"
        // The grey spreads from the anchored item, which sits in the menu bar 15px above the stage
        style={stageOrigin(position)}
      />
      <div className="page">
        <Hero />
        <div
          ref={flowStage}
          className="shutter -mx-[clamp(1.25rem,4vw,3rem)] mt-14 scroll-mt-[30px] rounded-tl-[72px] bg-stage px-[clamp(1.25rem,4vw,3rem)] py-12 desk:contents"
        >
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
  )
}
