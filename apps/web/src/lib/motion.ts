import type { CSSProperties } from 'react'

/** Entrance order for the first-load sequence in index.css (`--i` on `.rise`, headline lines, status items) */
export const order = (i: number) => ({ '--i': i }) as CSSProperties

/**
 * Marks each `.enter` element `.is-in` the first time it comes into view, which plays its
 * entrance (index.css). Once only: observed elements are dropped after they reveal.
 */
export function revealOnScroll(): () => void {
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue
        e.target.classList.add('is-in')
        io.unobserve(e.target)
      }
    },
    { rootMargin: '0px 0px -8% 0px' },
  )
  document.querySelectorAll('.enter').forEach((el) => io.observe(el))
  return () => io.disconnect()
}
