import type { ReactNode } from 'react'
import { Icon, type IconName } from '../Icon'

type SectionProps = {
  icon: IconName
  title: string
  /** Right-aligned headline value, e.g. "23%" */
  value?: ReactNode
  children?: ReactNode
}

/** One block of the dropdown: `Label(title, systemImage:)` + value, then detail lines */
export function Section({ icon, title, value, children }: SectionProps) {
  return (
    <section className="grid gap-1">
      <div className="flex items-center gap-2 font-semibold">
        <Icon name={icon} className="size-[15px]" />
        <span className="flex-1">{title}</span>
        {value}
      </div>
      {children}
    </section>
  )
}

export function Caption({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`text-[11px] text-secondary ${className}`}>{children}</div>
}

/** "↓ 1.4 MB/s ……… ↑ 120 KB/s", used by Network and Disk */
export function InOutRow({ down, up }: { down: string; up: string }) {
  return (
    <div className="flex items-center gap-2 text-xs tabular-nums">
      <Icon name="arrowDown" className="size-[11px]" />
      <span className="flex-1">{down}</span>
      <Icon name="arrowUp" className="size-[11px]" />
      <span>{up}</span>
    </div>
  )
}

export function Divider() {
  return <hr className="my-3 border-separator" />
}
