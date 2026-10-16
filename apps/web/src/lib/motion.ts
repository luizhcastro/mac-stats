import type { CSSProperties } from 'react'

/** Entrance order for `.rise` (index.css): each step starts 90ms after the previous one */
export const order = (i: number) => ({ '--i': i }) as CSSProperties
