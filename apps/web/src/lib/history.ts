import type { HistoryMetric, LiveStats } from '../hooks/useLiveStats'
import { seededRandom } from './random'

/** The app keeps three rings per metric: 60 × 1 s, 360 × 10 s and 1440 × 1 min */
export type HistoryRange = 'minute' | 'hour' | 'day'

export const HISTORY_RANGES: { id: HistoryRange; label: string }[] = [
  { id: 'minute', label: '1m' },
  { id: 'hour', label: '1h' },
  { id: 'day', label: '24h' },
]

const BASELINE: Record<HistoryMetric, { base: number; swing: number }> = {
  cpu: { base: 24, swing: 14 },
  memory: { base: 68, swing: 6 },
  netIn: { base: 1.2, swing: 1.4 },
  netOut: { base: 0.12, swing: 0.15 },
  diskRead: { base: 2.4, swing: 2.6 },
  diskWrite: { base: 1, swing: 1.1 },
  temperature: { base: 52, swing: 6 },
}

/**
 * Hour/day series are generated once (seeded, so they never change between loads):
 * a slow wave plus noise, which is roughly what averaged-down samples look like.
 */
function generate(metric: HistoryMetric, length: number, seed: number): number[] {
  const random = seededRandom(seed)
  const { base, swing } = BASELINE[metric]
  return Array.from({ length }, (_, i) => {
    const wave = Math.sin((i / length) * Math.PI * 4 + seed) * 0.5
    return Math.max(0, base + swing * (wave + (random() - 0.5) * 0.4))
  })
}

const METRICS = Object.keys(BASELINE) as HistoryMetric[]
const LONG_HISTORY: Record<'hour' | 'day', Record<HistoryMetric, number[]>> = {
  hour: Object.fromEntries(METRICS.map((m, i) => [m, generate(m, 360, i + 1)])) as Record<HistoryMetric, number[]>,
  day: Object.fromEntries(METRICS.map((m, i) => [m, generate(m, 1440, i + 101)])) as Record<HistoryMetric, number[]>,
}

export function historyFor(stats: LiveStats, metric: HistoryMetric, range: HistoryRange): number[] {
  return range === 'minute' ? stats.history[metric] : LONG_HISTORY[range][metric]
}

/** Round a chart's max up to a tidy value so the scale doesn't jump every tick */
export function niceMax(values: number[], minimum: number): number {
  const peak = Math.max(minimum, ...values)
  const magnitude = 10 ** Math.floor(Math.log10(peak))
  return Math.ceil(peak / magnitude) * magnitude
}
