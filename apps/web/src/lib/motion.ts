import type { CSSProperties } from 'react'

/** Entrance order for the first-load sequence in index.css (`--i` on `.rise`, headline lines, status items, sections) */
export const order = (i: number) => ({ '--i': i }) as CSSProperties

