import { useState, type ReactNode } from 'react'
import { Icon, type IconName } from '../Icon'

type SectionProps = {
  icon: IconName
  title: string
  /** Right-aligned headline value, e.g. "23%"; stays visible while collapsed */
  value?: ReactNode
  /** Detail lines. Without them the section is a single row with no chevron (Network). */
  children?: ReactNode
  defaultOpen?: boolean
}

/**
 * One block of the dropdown, mirrors `PopoverSection` in MenuBarContentView.swift: the header
 * row toggles the detail below it, which slides open (grid 0fr → 1fr) and fades in.
 */
export function Section({ icon, title, value, children, defaultOpen = false }: SectionProps) {
  const [open, setOpen] = useState(defaultOpen)
  const collapsible = children !== undefined

  const header = (
    <>
      <span className="flex w-3.5 flex-none">
        {collapsible && (
          <Icon
            name="chevron"
            className={`size-[9px] stroke-[2.2] text-secondary transition-transform duration-300 ease-snappy motion-reduce:transition-none ${open ? 'rotate-90' : ''}`}
          />
        )}
      </span>
      <Icon name={icon} className="size-[15px]" />
      <span className="flex-1 whitespace-nowrap">{title}</span>
      {value}
    </>
  )

  return (
    <section>
      {collapsible ? (
        <button
          type="button"
          aria-expanded={open}
          onClick={() => setOpen(!open)}
          className="flex w-full cursor-pointer items-center gap-2 text-left font-semibold"
        >
          {header}
        </button>
      ) : (
        <div className="flex items-center gap-2 font-semibold">{header}</div>
      )}
      {collapsible && (
        <div
          className={`grid transition-[grid-template-rows,opacity] duration-300 ease-snappy motion-reduce:duration-150 ${
            open ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'
          }`}
        >
          <div className="min-h-0 overflow-hidden" inert={!open}>
            <div className="grid grid-cols-[minmax(0,1fr)] gap-1 pt-1 pl-[22px]">{children}</div>
          </div>
        </div>
      )}
    </section>
  )
}

export function Caption({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`text-[11px] whitespace-nowrap text-secondary ${className}`}>{children}</div>
}

/** "↓ 1.4 MB/s  ↑ 120 KB/s", the right side of the Network row and Disk's detail */
export function InOutRow({ down, up }: { down: string; up: string }) {
  return (
    <div className="flex items-center gap-2 text-xs whitespace-nowrap tabular-nums">
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
