import type { CSSProperties, Ref } from 'react'
import { AppGlyph, Icon, type IconName } from '../Icon'

type MenuBarItemProps = {
  label: string
  /** Metric id, reported to analytics when the item is clicked */
  metric: string
  onClick: () => void
  /** Highlighted while its dropdown is open, like an NSStatusItem button */
  active?: boolean
  /** Act out the load sequence's click (index.css .press-enter); only for the first open */
  introClick?: boolean
  style?: CSSProperties
  ref?: Ref<HTMLButtonElement>
} & ({ icon: IconName; value: string; width: number } | { appIcon: true })

/**
 * One status item. Mirrors SingleMetricLabel.swift: a 9pt symbol above a 9pt bold
 * monospaced-digit value in a fixed-width slot, or the bare app icon.
 */
export function MenuBarItem(props: MenuBarItemProps) {
  return (
    <button
      ref={props.ref}
      type="button"
      aria-label={props.label}
      data-umami-event="Menu bar item"
      data-umami-event-metric={props.metric}
      onClick={props.onClick}
      style={props.style}
      className={`flex h-6 cursor-pointer flex-col items-center justify-center rounded-md px-1 text-[9px] leading-none font-bold tabular-nums hover:bg-white/18 ${
        props.active ? `bg-white/18 ${props.introClick ? 'press-enter' : ''}` : ''
      }`}
    >
      {'appIcon' in props ? (
        <AppGlyph className="size-4" />
      ) : (
        <>
          <Icon name={props.icon} className="size-2.5 stroke-[1.7]" />
          <span className="text-center" style={{ width: props.width }}>
            {props.value}
          </span>
        </>
      )}
    </button>
  )
}
