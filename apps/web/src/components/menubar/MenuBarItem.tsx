import type { Ref } from 'react'
import { Icon, type IconName } from '../Icon'

type MenuBarItemProps = {
  label: string
  onClick: () => void
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
      onClick={props.onClick}
      className="flex h-6 cursor-pointer flex-col items-center justify-center rounded-md px-1 text-[9px] leading-none font-bold tabular-nums hover:bg-white/18"
    >
      {'appIcon' in props ? (
        <img src="/icon.png" alt="" className="size-[17px]" />
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
