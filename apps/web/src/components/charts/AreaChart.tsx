import { useId } from 'react'

export type ChartSeries = { values: number[]; color: string }

type AreaChartProps = {
  series: ChartSeries[]
  max: number
  /** Rendered height in px; width always fills the container */
  height?: number
  /** Fill under the line (AreaSpark) or line only, like the dual network/disk charts */
  filled?: boolean
}

const WIDTH = 100

/** Line + gradient area, the web twin of AreaSpark / DualAreaSpark in PaneKit.swift */
export function AreaChart({ series, max, height = 80, filled = true }: AreaChartProps) {
  const id = useId()

  return (
    <svg viewBox={`0 0 ${WIDTH} ${height}`} preserveAspectRatio="none" className="w-full" style={{ height }} aria-hidden="true">
      {series.map(({ values, color }, i) => {
        const line = toPoints(values, max, height)
        const gradientId = `${id}-${i}`
        return (
          <g key={i}>
            {filled && (
              <>
                <defs>
                  <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0" stopColor={color} stopOpacity="0.45" />
                    <stop offset="1" stopColor={color} stopOpacity="0.05" />
                  </linearGradient>
                </defs>
                <polygon points={`0,${height} ${line} ${WIDTH},${height}`} fill={`url(#${gradientId})`} />
              </>
            )}
            <polyline points={line} fill="none" stroke={color} strokeWidth="1.4" vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
          </g>
        )
      })}
    </svg>
  )
}

function toPoints(values: number[], max: number, height: number): string {
  const lastIndex = Math.max(1, values.length - 1)
  return values
    .map((v, i) => {
      const x = (i / lastIndex) * WIDTH
      const y = height * (1 - Math.min(v, max) / max)
      return `${x.toFixed(2)},${y.toFixed(2)}`
    })
    .join(' ')
}
