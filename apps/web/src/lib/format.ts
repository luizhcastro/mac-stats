import type { Process } from '../data/processes'
import type { ProcessTab } from './metrics'

/** Megabytes per second → "1.4 MB/s" / "512.3 KB/s" / "80 B/s", like `Fmt.rate` */
export function formatRate(mbPerSec: number): string {
  if (mbPerSec >= 1) return `${mbPerSec.toFixed(1)} MB/s`
  if (mbPerSec >= 0.001) return `${(mbPerSec * 1000).toFixed(1)} KB/s`
  return `${(mbPerSec * 1_000_000).toFixed(0)} B/s`
}

/** Table-cell rate → "1.2 M/s" / "340 K/s" / "0 K/s", like `Fmt.compactRate` */
export function formatCompactRate(mbPerSec: number): string {
  if (mbPerSec >= 1) return `${mbPerSec.toFixed(1)} M/s`
  if (mbPerSec >= 0.001) return `${(mbPerSec * 1000).toFixed(0)} K/s`
  return '0 K/s'
}

/** Gigabytes → "10.46 GB" / "16 GB" / "598 MB", like `Fmt.bytes` (ByteCountFormatter drops trailing zeros) */
export function formatGB(gb: number): string {
  return gb >= 1 ? `${Number(gb.toFixed(2))} GB` : `${(gb * 1000).toFixed(0)} MB`
}

export function formatPercent(value: number, digits = 0): string {
  return `${value.toFixed(digits)}%`
}

/** Value shown for a process in the dropdown / leader lists, per tab */
export function processValue(tab: ProcessTab, p: Process): number {
  switch (tab) {
    case 'cpu':
      return p.cpu
    case 'ram':
      return p.memoryGB
    case 'disk':
      return p.diskRead + p.diskWrite
    case 'net':
      return p.netIn + p.netOut
    case 'energy':
      return p.energy
  }
}

export function formatProcessValue(tab: ProcessTab, p: Process): string {
  const value = processValue(tab, p)
  switch (tab) {
    case 'cpu':
      return formatPercent(value, 2)
    case 'ram':
      return formatGB(value)
    case 'disk':
    case 'net':
      return formatRate(value)
    case 'energy':
      return `${value.toFixed(1)} EI`
  }
}

export function topProcesses(processes: Process[], tab: ProcessTab, count: number): Process[] {
  return [...processes].sort((a, b) => processValue(tab, b) - processValue(tab, a)).slice(0, count)
}
