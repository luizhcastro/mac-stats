import type { ReactNode } from 'react'
import type { Process } from '../../data/processes'
import { formatProcessValue, topProcesses } from '../../lib/format'
import { HISTORY_RANGES, type HistoryRange } from '../../lib/history'
import type { ProcessTab } from '../../lib/metrics'
import { Icon, type IconName } from '../Icon'

/** Shared building blocks for the window panes, mirroring PaneKit.swift */

/** ScrollView > VStack(spacing: 16).padding(24) */
export function Pane({ children }: { children: ReactNode }) {
  return <div className="grid gap-4 p-6">{children}</div>
}

type PaneHeaderProps = { title: string; subtitle?: string; trailing?: ReactNode }

export function PaneHeader({ title, subtitle, trailing }: PaneHeaderProps) {
  return (
    <div className="flex items-baseline justify-between gap-4 pb-3">
      <div className="grid gap-0.5">
        <h3 className="text-[22px] leading-tight font-semibold">{title}</h3>
        {subtitle && <p className="text-[13px] text-secondary">{subtitle}</p>}
      </div>
      {trailing}
    </div>
  )
}

type MetricCardProps = { title: string; icon: IconName; children: ReactNode }

/** Rounded card with a small uppercase title, like MetricCard */
export function MetricCard({ title, icon, children }: MetricCardProps) {
  return (
    <div className="grid min-w-0 grid-cols-[minmax(0,1fr)] content-start gap-2.5 rounded-xl border border-white/6 bg-white/4 p-4">
      <div className="flex items-center gap-1.5 text-xs font-medium text-secondary uppercase">
        <Icon name={icon} className="size-3.5" />
        {title}
      </div>
      {children}
    </div>
  )
}

/** `HStack(spacing: 16)` of equal-width cards; wraps on narrow screens */
export function CardRow({ children }: { children: ReactNode }) {
  return <div className="grid auto-cols-fr gap-4 sm:grid-flow-col">{children}</div>
}

/** Overview's `GridItem(.adaptive(minimum: 280))` */
export function CardGrid({ children }: { children: ReactNode }) {
  return <div className="grid grid-cols-[repeat(auto-fill,minmax(min(280px,100%),1fr))] gap-4">{children}</div>
}

type ValueProps = {
  children: ReactNode
  /** Point size used by the Swift view: 36 (hero), 28 (overview), 24/22/20 (small cards) */
  size: 36 | 28 | 24 | 22 | 20
  color?: string
}

const VALUE_SIZES = { 36: 'text-[36px]', 28: 'text-[28px]', 24: 'text-2xl', 22: 'text-[22px]', 20: 'text-xl' }

/** `.font(.system(size: N, weight: .semibold)).monospacedDigit()` */
export function Value({ children, size, color }: ValueProps) {
  return (
    <span className={`${VALUE_SIZES[size]} leading-none font-semibold whitespace-nowrap tabular-nums`} style={{ color }}>
      {children}
    </span>
  )
}

/** Value + optional "of 16 GB" on the baseline, and optional caption pushed to the right */
export function ValueLine({ children, trailing }: { children: ReactNode; trailing?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
      {children}
      {trailing && <span className="ml-auto text-xs">{trailing}</span>}
    </div>
  )
}

export function Secondary({ children }: { children: ReactNode }) {
  return <span className="whitespace-nowrap text-secondary">{children}</span>
}

/** Caption label above a big colored rate ("Read" / "1.4 MB/s"), from the throughput cards */
export function LabeledRate({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div className="grid gap-0.5">
      <span className="text-xs text-secondary">{label}</span>
      <Value size={22} color={color}>
        {value}
      </Value>
    </div>
  )
}

/** "↓ 1.4 MB/s" with a colored arrow, used in the overview network and disk cards */
export function RateLabel({ direction, color, value }: { direction: 'down' | 'up'; color: string; value: string }) {
  return (
    <span className="flex items-center gap-1 text-sm whitespace-nowrap tabular-nums">
      <span style={{ color }}>
        <Icon name={direction === 'down' ? 'arrowDown' : 'arrowUp'} className="size-3.5" />
      </span>
      {/* widest form is "999.9 KB/s"; reserve it so unit/digit changes don't shift the row */}
      <span className="min-w-[10ch]">{value}</span>
    </span>
  )
}

export function StatRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 text-sm">
      <span className="text-secondary">{label}</span>
      <span className="text-right tabular-nums">{value}</span>
    </div>
  )
}

type RangePickerProps = { value: HistoryRange; onChange: (range: HistoryRange) => void }

/** 1m / 1h / 24h segmented control, 160pt wide like HistoryRangePicker */
export function RangePicker({ value, onChange }: RangePickerProps) {
  return (
    <div role="tablist" className="grid w-40 grid-cols-3 rounded-lg bg-white/8 p-0.5 text-xs">
      {HISTORY_RANGES.map((range) => (
        <button
          key={range.id}
          type="button"
          role="tab"
          aria-selected={range.id === value}
          onClick={() => onChange(range.id)}
          className="cursor-pointer rounded-md py-0.5 aria-selected:bg-white/20 aria-selected:shadow-sm"
        >
          {range.label}
        </button>
      ))}
    </div>
  )
}

export function rangeLabel(range: HistoryRange): string {
  return HISTORY_RANGES.find((r) => r.id === range)!.label
}

/** Top 8 processes for a metric with PID and value, like LeaderList */
export function LeaderList({ processes, tab }: { processes: Process[]; tab: ProcessTab }) {
  return (
    <ul className="divide-y divide-white/8 text-[13px]">
      {topProcesses(processes, tab, 8).map((p) => (
        <li key={p.pid} className="flex items-center gap-2 py-1.5">
          <span className="flex-1 truncate">{p.name}</span>
          <span className="text-[11px] text-tertiary tabular-nums">{p.pid}</span>
          <span className="min-w-[70px] text-right text-secondary tabular-nums">{formatProcessValue(tab, p)}</span>
          <Icon name="ellipsis" className="size-3.5 text-secondary" />
        </li>
      ))}
    </ul>
  )
}
