type SegmentedProps<T extends string> = {
  options: readonly { id: T; label: string }[]
  value: T
  onChange: (value: T) => void
  className?: string
}

/**
 * Capsule segmented control whose selection pill slides to the clicked segment, mirrors
 * `SlidingSegmented` in PaneKit.swift. Segments are equal width, so the pill is one
 * segment wide and moves by whole widths (transform only).
 */
export function Segmented<T extends string>({ options, value, onChange, className = '' }: SegmentedProps<T>) {
  const index = Math.max(0, options.findIndex((o) => o.id === value))

  return (
    <div role="tablist" className={`relative grid auto-cols-fr grid-flow-col rounded-full bg-white/8 p-0.5 ${className}`}>
      <span
        aria-hidden="true"
        className="absolute inset-y-0.5 left-0.5 rounded-full bg-accent shadow-[inset_0_0.5px_0_rgb(255_255_255/0.35)] transition-transform duration-300 ease-snappy motion-reduce:transition-none"
        style={{ width: `calc((100% - 4px) / ${options.length})`, transform: `translateX(${index * 100}%)` }}
      />
      {options.map((option) => {
        const selected = option.id === value
        return (
          <button
            key={option.id}
            type="button"
            role="tab"
            aria-selected={selected}
            onClick={() => onChange(option.id)}
            className={`relative cursor-pointer rounded-full py-0.5 transition-colors duration-300 ease-snappy ${
              selected ? 'font-medium text-on-accent' : ''
            }`}
          >
            {option.label}
          </button>
        )
      })}
    </div>
  )
}
