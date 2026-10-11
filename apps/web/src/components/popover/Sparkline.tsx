/** CPU history line, same idea as `Sparkline` in MenuBarContentView.swift */
export function Sparkline({ values, max }: { values: number[]; max: number }) {
  const points = values
    .map((v, i) => `${(i / (values.length - 1)) * 100},${28 * (1 - Math.min(v, max) / max)}`)
    .join(' ')

  return (
    <svg viewBox="0 0 100 28" preserveAspectRatio="none" className="h-7 w-full" aria-hidden="true">
      <polyline points={points} className="fill-none stroke-accent stroke-[1.5]" vectorEffect="non-scaling-stroke" />
    </svg>
  )
}
