import { BAR_METRICS, type BarMetric } from '../../lib/metrics'
import { Icon } from '../Icon'
import { Caption } from './Section'

type MenuBarPrefsProps = {
  visible: Set<BarMetric>
  onToggle: (metric: BarMetric) => void
}

/** "Show in menu bar" checkbox grid, mirrors MenuBarPrefsView.swift */
export function MenuBarPrefs({ visible, onToggle }: MenuBarPrefsProps) {
  return (
    <section>
      <Caption>Show in menu bar</Caption>
      <div className="mt-1 grid grid-cols-3 gap-x-2.5 gap-y-1.5 text-[11px]">
        {BAR_METRICS.map(({ id, label, icon }) => {
          const checked = visible.has(id)
          // The app never lets you hide the last item
          const locked = checked && visible.size === 1
          return (
            <label key={id} className="flex cursor-pointer items-center gap-1.5 whitespace-nowrap">
              <input
                type="checkbox"
                checked={checked}
                disabled={locked}
                onChange={() => onToggle(id)}
                className="peer sr-only"
              />
              <span
                aria-hidden="true"
                className="mr-1 grid size-3.5 place-items-center rounded bg-white/10 peer-checked:bg-accent peer-focus-visible:outline-3 peer-focus-visible:outline-white/60 peer-disabled:opacity-60"
              >
                {checked && (
                  <svg viewBox="0 0 10 10" className="size-2.5 fill-none stroke-on-accent stroke-[1.8]">
                    <path d="M2 5.2 4.2 7.4 8 2.8" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                )}
              </span>
              <Icon name={icon} className="size-3" />
              {label}
            </label>
          )
        })}
      </div>
    </section>
  )
}
