import { useEffect, useState } from 'react'
import { BASE_PROCESSES, type Process } from '../data/processes'
import { bursty, jitter } from '../lib/random'

/**
 * Fake live numbers shared by the menu bar, the dropdown and the main window replica.
 * Everything drifts a little every second so it reads like the real app without
 * measuring anything. Rates are in MB/s, sizes in GB, temperatures in °C.
 */

export type HistoryMetric = 'cpu' | 'memory' | 'netIn' | 'netOut' | 'diskRead' | 'diskWrite' | 'temperature'

export type LiveStats = {
  cpu: { total: number; user: number; system: number; perCore: number[]; load: [number, number, number] }
  memory: {
    usedGB: number
    totalGB: number
    activeGB: number
    wiredGB: number
    compressedGB: number
    freeGB: number
    pressure: number
    swapUsedGB: number
    swapTotalGB: number
  }
  network: { in: number; out: number; sessionInGB: number; sessionOutGB: number }
  disk: { read: number; write: number }
  temperature: { cpu: number; gpu: number; max: number; sensors: number }
  gpu: { utilization: number; renderer: number; tiler: number; vramGB: number }
  fans: { name: string; rpm: number; target: number; min: number; max: number }[]
  /** Last 60 seconds of each charted metric, oldest first */
  history: Record<HistoryMetric, number[]>
  processes: Process[]
}

const HISTORY_LENGTH = 60
// Apple Silicon layout: performance cores first, then efficiency cores
export const PERFORMANCE_CORES = 6
export const EFFICIENCY_CORES = 4

function sampleProcesses(): Process[] {
  return BASE_PROCESSES.map((p) => ({
    ...p,
    cpu: jitter(p.cpu, 0.3),
    memoryGB: jitter(p.memoryGB, 0.02),
    diskRead: bursty(p.diskRead),
    diskWrite: bursty(p.diskWrite),
    netIn: bursty(p.netIn),
    netOut: bursty(p.netOut),
    energy: jitter(p.energy, 0.3),
  }))
}

function sample(previous?: LiveStats): LiveStats {
  const total = jitter(23, 0.5)
  const usedGB = jitter(11.2, 0.02)
  const netIn = bursty(1.4)
  const diskRead = bursty(2.9)
  const temperature = jitter(54, 0.05)

  const current = {
    cpu: total,
    memory: (usedGB / 16) * 100,
    netIn,
    netOut: netIn * 0.09,
    diskRead,
    diskWrite: diskRead * 0.4,
    temperature,
  }
  const history = Object.fromEntries(
    (Object.keys(current) as HistoryMetric[]).map((metric) => {
      const past = previous?.history[metric] ?? seedHistory(metric)
      return [metric, [...past.slice(1), current[metric]]]
    }),
  ) as Record<HistoryMetric, number[]>

  return {
    cpu: {
      total,
      user: total * 0.62,
      system: total * 0.38,
      perCore: Array.from({ length: PERFORMANCE_CORES + EFFICIENCY_CORES }, (_, i) =>
        Math.min(100, jitter(i < PERFORMANCE_CORES ? total * 1.3 : total * 0.6, 0.9)),
      ),
      load: [jitter(2.31, 0.1), jitter(2.1, 0.05), 1.98],
    },
    memory: {
      usedGB,
      totalGB: 16,
      activeGB: usedGB * 0.55,
      wiredGB: 2.1,
      compressedGB: jitter(1.3, 0.05),
      freeGB: 16 - usedGB,
      pressure: (usedGB / 16) * 60,
      swapUsedGB: 0.4,
      swapTotalGB: 2,
    },
    network: {
      in: current.netIn,
      out: current.netOut,
      sessionInGB: (previous?.network.sessionInGB ?? 3.42) + current.netIn / 1024,
      sessionOutGB: (previous?.network.sessionOutGB ?? 0.61) + current.netOut / 1024,
    },
    disk: { read: current.diskRead, write: current.diskWrite },
    temperature: { cpu: temperature, gpu: temperature - 6, max: temperature + 7, sensors: 24 },
    gpu: { utilization: jitter(18, 0.6), renderer: jitter(15, 0.6), tiler: jitter(9, 0.6), vramGB: jitter(1.8, 0.05) },
    fans: [{ name: 'Left Fan', rpm: Math.round(jitter(2310, 0.04)), target: 2300, min: 1200, max: 5800 }],
    history,
    processes: sampleProcesses(),
  }
}

function seedHistory(metric: HistoryMetric): number[] {
  const base = { cpu: 22, memory: 70, netIn: 1.4, netOut: 0.12, diskRead: 2.9, diskWrite: 1.2, temperature: 54 }[metric]
  const isRate = metric !== 'cpu' && metric !== 'memory' && metric !== 'temperature'
  return Array.from({ length: HISTORY_LENGTH }, () =>
    isRate ? bursty(base) : jitter(base, metric === 'cpu' ? 0.6 : 0.03),
  )
}

export function useLiveStats(): LiveStats {
  const [stats, setStats] = useState(() => sample())

  useEffect(() => {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const timer = setInterval(() => setStats((previous) => sample(previous)), 1000)
    return () => clearInterval(timer)
  }, [])

  return stats
}
