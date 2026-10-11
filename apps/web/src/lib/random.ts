/** `value` ± `spread / 2` as a fraction, never negative */
export function jitter(value: number, spread: number): number {
  return Math.max(0, value * (1 + (Math.random() - 0.5) * spread))
}

/** Mostly quiet traffic with the occasional burst, like disk and network look in practice */
export function bursty(base: number): number {
  const quiet = base * (0.2 + Math.random() * 0.5)
  return Math.random() < 0.08 ? quiet * (4 + Math.random() * 8) : quiet
}

/** Small seeded PRNG so the long-range charts look the same on every load */
export function seededRandom(seed: number): () => number {
  let state = seed
  return () => {
    state = (state + 0x6d2b79f5) | 0
    let t = Math.imul(state ^ (state >>> 15), 1 | state)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
