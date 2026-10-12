import { useLayoutEffect, useRef } from 'react'

/**
 * FLIP for a keyed list: after each render, children whose key moved slide from their old
 * position to the new one (transform only), so a re-rank or tab switch reads as rows moving
 * instead of text swapping. Rows tag themselves with `data-flip-key`. Off under Reduce Motion.
 */
export function useFlip<T extends HTMLElement>(deps: unknown[]) {
  const ref = useRef<T>(null)
  const last = useRef(new Map<string, number>())

  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches
    const next = new Map<string, number>()
    for (const child of el.querySelectorAll<HTMLElement>('[data-flip-key]')) {
      const key = child.dataset.flipKey!
      const top = child.offsetTop
      next.set(key, top)
      const before = last.current.get(key)
      if (reduce || before === undefined || before === top) continue
      child.animate([{ transform: `translateY(${before - top}px)` }, { transform: 'none' }], {
        duration: 300,
        easing: 'cubic-bezier(0.23, 1, 0.32, 1)',
      })
    }
    last.current = next
  }, deps)

  return ref
}
