import { useLayoutEffect, useState } from 'react'

const POPOVER_WIDTH = 340
const EDGE_MARGIN = 8
const FLOATING_QUERY = '(min-width: 1180px)' // keep in sync with --breakpoint-desk

export type PopoverPosition = {
  /** Left edge of the popover, in px from the viewport's left */
  left: number
  /** Center of the arrow, in px from the popover's left edge */
  arrow: number
}

/**
 * Positions the dropdown under the clicked menu bar item, like NSPopover does.
 * Returns null on narrow screens, where the dropdown sits in the page flow instead.
 * `deps` should change whenever the anchor might have moved (e.g. items shown/hidden).
 */
export function usePopoverAnchor(getAnchor: () => HTMLElement | null | undefined, deps: unknown[]): PopoverPosition | null {
  const [position, setPosition] = useState<PopoverPosition | null>(null)

  useLayoutEffect(() => {
    function place() {
      const anchor = getAnchor()
      if (!anchor || !matchMedia(FLOATING_QUERY).matches) return setPosition(null)
      const rect = anchor.getBoundingClientRect()
      const center = rect.left + rect.width / 2
      // clientWidth, not innerWidth: a classic (non-overlay) scrollbar takes width out of the viewport
      const maxLeft = document.documentElement.clientWidth - POPOVER_WIDTH - EDGE_MARGIN
      const left = Math.min(Math.max(center - POPOVER_WIDTH / 2, EDGE_MARGIN), maxLeft)
      setPosition({ left, arrow: center - left })
    }

    place()
    window.addEventListener('resize', place)
    return () => window.removeEventListener('resize', place)
  }, deps)

  return position
}
