type CenteredChartProps = { values: number[]; color: string; height?: number }

const WIDTH = 100

/**
 * Signed series around a zero line (charge above, drain below), like CenteredSpark in
 * PaneKit.swift: symmetric scale, faint fill to zero and a hairline at zero.
 */
export function CenteredChart({ values, color, height = 100 }: CenteredChartProps) {
  const absMax = Math.max(0.5, ...values.map(Math.abs))
  const mid = height / 2
  const lastIndex = Math.max(1, values.length - 1)
  const line = values
    .map((v, i) => `${((i / lastIndex) * WIDTH).toFixed(2)},${(mid - (v / absMax) * mid).toFixed(2)}`)
    .join(' ')

  return (
    <svg viewBox={`0 0 ${WIDTH} ${height}`} preserveAspectRatio="none" className="w-full" style={{ height }} aria-hidden="true">
      <polygon points={`0,${mid} ${line} ${WIDTH},${mid}`} fill={color} fillOpacity="0.18" />
      <line x1="0" x2={WIDTH} y1={mid} y2={mid} stroke="rgb(235 235 245 / 0.35)" strokeWidth="0.5" vectorEffect="non-scaling-stroke" />
      <polyline points={line} fill="none" stroke={color} strokeWidth="1.6" vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
    </svg>
  )
}
