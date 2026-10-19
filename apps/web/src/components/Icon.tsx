import { useId, type ReactNode } from 'react'

/** Line-art stand-ins for the SF Symbols the app uses, drawn on a 16×16 grid */
const PATHS = {
  cpu: (
    <>
      <rect x="4" y="4" width="8" height="8" rx="1.5" />
      <path d="M6 1.5v2M10 1.5v2M6 12.5v2M10 12.5v2M1.5 6h2M1.5 10h2M12.5 6h2M12.5 10h2" />
    </>
  ),
  thermometer: <path d="M6.5 9.5V3a1.5 1.5 0 0 1 3 0v6.5a3 3 0 1 1-3 0Z" />,
  memorychip: (
    <>
      <rect x="1.5" y="4.5" width="13" height="6" rx="1" />
      <path d="M4 10.5v2M7 10.5v2M10 10.5v2M13 10.5v2" />
    </>
  ),
  internaldrive: (
    <>
      <rect x="1.5" y="5" width="13" height="6.5" rx="1.5" />
      <circle cx="11.5" cy="8.25" r=".6" />
    </>
  ),
  network: (
    <>
      <circle cx="8" cy="8" r="6.5" />
      <path d="M1.5 8h13M8 1.5c2 2 2.6 4 2.6 6.5S10 12.5 8 14.5M8 1.5C6 3.5 5.4 5.5 5.4 8S6 12.5 8 14.5" />
    </>
  ),
  app: (
    <>
      <rect x="1.5" y="3.5" width="11" height="11" rx="3" />
      <circle cx="12.5" cy="3.5" r="2.2" fill="currentColor" stroke="none" />
    </>
  ),
  battery: (
    <>
      <rect x="1" y="4.5" width="12.5" height="7" rx="2" />
      <rect x="2.5" y="6" width="8.5" height="4" rx=".8" fill="currentColor" stroke="none" />
      <path d="M15 7v2" />
    </>
  ),
  macwindow: (
    <>
      <rect x="1.5" y="2.5" width="13" height="11" rx="2" />
      <path d="M1.5 5.5h13" />
    </>
  ),
  grid: (
    <>
      <rect x="2" y="2" width="5" height="5" rx="1" />
      <rect x="9" y="2" width="5" height="5" rx="1" />
      <rect x="2" y="9" width="5" height="5" rx="1" />
      <rect x="9" y="9" width="5" height="5" rx="1" />
    </>
  ),
  display: (
    <>
      <rect x="1.5" y="2.5" width="13" height="8.5" rx="1.2" />
      <path d="M6 14h4M8 11v3" />
    </>
  ),
  fan: (
    <>
      <circle cx="8" cy="8" r="1.3" />
      <path d="M8 6.7C7 4.5 7.3 2 9.5 2c1.7 0 1.6 2.6-1.5 4.7M9.3 8c2.2-1 4.7-.7 4.7 1.5 0 1.7-2.6 1.6-4.7-1.5M8 9.3c1 2.2.7 4.7-1.5 4.7C4.8 14 4.9 11.4 8 9.3M6.7 8C4.5 9 2 8.7 2 6.5 2 4.8 4.6 4.9 6.7 8" />
    </>
  ),
  list: (
    <>
      <rect x="1.5" y="2.5" width="13" height="11" rx="1.5" />
      <path d="M4 6h1M7 6h5M4 8.5h1M7 8.5h5M4 11h1M7 11h5" />
    </>
  ),
  // gear / gearshape: 8-tooth cog with a round hole
  gear: (
    <>
      <path d="M6.63 3.09 L6.59 1.55 L9.41 1.55 L9.37 3.09 L10.50 3.56 L11.56 2.44 L13.56 4.44 L12.44 5.50 L12.91 6.63 L14.45 6.59 L14.45 9.41 L12.91 9.37 L12.44 10.50 L13.56 11.56 L11.56 13.56 L10.50 12.44 L9.37 12.91 L9.41 14.45 L6.59 14.45 L6.63 12.91 L5.50 12.44 L4.44 13.56 L2.44 11.56 L3.56 10.50 L3.09 9.37 L1.55 9.41 L1.55 6.59 L3.09 6.63 L3.56 5.50 L2.44 4.44 L4.44 2.44 L5.50 3.56Z" />
      <circle cx="8" cy="8" r="2.1" />
    </>
  ),
  // menubar.rectangle: screen with a filled strip along the top
  menubar: (
    <>
      <rect x="1.5" y="2.5" width="13" height="11" rx="2" />
      <path d="M1.5 4.5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1h-13Z" fill="currentColor" />
    </>
  ),
  // dock.rectangle: screen with a small filled dock along the bottom
  dock: (
    <>
      <rect x="1.5" y="2.5" width="13" height="11" rx="2" />
      <rect x="4" y="10" width="8" height="1.8" rx=".9" fill="currentColor" stroke="none" />
    </>
  ),
  sidebar: (
    <>
      <rect x="1.5" y="2.5" width="13" height="11" rx="2" />
      <path d="M6 2.5v11M3 5h1.5M3 7h1.5" />
    </>
  ),
  search: (
    <>
      <circle cx="7" cy="7" r="4.5" />
      <path d="m10.3 10.3 3.7 3.7" />
    </>
  ),
  bolt: <path d="M9 1.5 3.5 9H8l-1 5.5L12.5 7H8l1-5.5Z" />,
  wifi: <path d="M1.8 6a9 9 0 0 1 12.4 0M4 8.4a6 6 0 0 1 8 0M6.2 10.8a3 3 0 0 1 3.6 0M8 13.2h0" />,
  gauge: (
    <>
      <path d="M2.5 11.5a6 6 0 1 1 11 0" />
      <path d="m8 9.5 2.5-3" />
    </>
  ),
  heart: <path d="M8 13.5S2 10 2 6a3 3 0 0 1 6-1 3 3 0 0 1 6 1c0 4-6 7.5-6 7.5Z" />,
  ellipsis: (
    <>
      <circle cx="8" cy="8" r="6.5" />
      <path d="M5 8h0M8 8h0M11 8h0" strokeWidth="1.8" />
    </>
  ),
  xmarkCircle: (
    <>
      <circle cx="8" cy="8" r="6.5" />
      <path d="m5.8 5.8 4.4 4.4M10.2 5.8l-4.4 4.4" />
    </>
  ),
  arrowDown: <path d="M8 2.5v11M3.5 9 8 13.5 12.5 9" />,
  arrowUp: <path d="M8 13.5v-11M3.5 7 8 2.5 12.5 7" />,
  chevron: <path d="m6 3.5 4.5 4.5L6 12.5" />,
  speaker: (
    <>
      <path d="M2 6h2.5L8 3v10L4.5 10H2Z" />
      <path d="M10.5 5.8a3 3 0 0 1 0 4.4M12.4 4a5.5 5.5 0 0 1 0 8" />
    </>
  ),
} satisfies Record<string, ReactNode>

export type IconName = keyof typeof PATHS

type IconProps = { name: IconName; className?: string }

export function Icon({ name, className = 'size-[1em]' }: IconProps) {
  return (
    <svg
      viewBox="0 0 16 16"
      className={`flex-none fill-none stroke-current stroke-[1.4] ${className}`}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[name]}
    </svg>
  )
}

/**
 * The menu bar's single-colour app icon, same 16-unit drawing as `AppIconLabel` in
 * SingleMetricLabel.swift: the icon's superellipse tile in the current colour with its three
 * rings and centre dot cut out.
 */
const GLYPH_TILE = 'M16.00 8.00L15.99 8.76L15.94 9.38L15.87 9.96L15.76 10.49L15.63 11.01L15.47 11.50L15.28 11.96L15.07 12.40L14.82 12.82L14.55 13.22L14.26 13.59L13.93 13.93L13.59 14.26L13.22 14.55L12.82 14.82L12.40 15.07L11.96 15.28L11.50 15.47L11.01 15.63L10.49 15.76L9.96 15.87L9.38 15.94L8.76 15.99L8.00 16.00L7.24 15.99L6.62 15.94L6.04 15.87L5.51 15.76L4.99 15.63L4.50 15.47L4.04 15.28L3.60 15.07L3.18 14.82L2.78 14.55L2.41 14.26L2.07 13.93L1.74 13.59L1.45 13.22L1.18 12.82L0.93 12.40L0.72 11.96L0.53 11.50L0.37 11.01L0.24 10.49L0.13 9.96L0.06 9.38L0.01 8.76L0.00 8.00L0.01 7.24L0.06 6.62L0.13 6.04L0.24 5.51L0.37 4.99L0.53 4.50L0.72 4.04L0.93 3.60L1.18 3.18L1.45 2.78L1.74 2.41L2.07 2.07L2.41 1.74L2.78 1.45L3.18 1.18L3.60 0.93L4.04 0.72L4.50 0.53L4.99 0.37L5.51 0.24L6.04 0.13L6.62 0.06L7.24 0.01L8.00 0.00L8.76 0.01L9.38 0.06L9.96 0.13L10.49 0.24L11.01 0.37L11.50 0.53L11.96 0.72L12.40 0.93L12.82 1.18L13.22 1.45L13.59 1.74L13.93 2.07L14.26 2.41L14.55 2.78L14.82 3.18L15.07 3.60L15.28 4.04L15.47 4.50L15.63 4.99L15.76 5.51L15.87 6.04L15.94 6.62L15.99 7.24Z'
const GLYPH_RINGS = 'M8 3A5 5 0 1 1 3.01 8.25 M8 4.4A3.6 3.6 0 1 1 6.19 11.11 M8 5.8A2.2 2.2 0 0 1 9.10 9.91'

export function AppGlyph({ className = 'size-4' }: { className?: string }) {
  const mask = useId()
  return (
    <svg viewBox="0 0 16 16" className={className} aria-hidden="true">
      <mask id={mask}>
        <path d={GLYPH_TILE} fill="white" />
        <path d={GLYPH_RINGS} fill="none" stroke="black" strokeWidth="0.85" strokeLinecap="round" />
        <circle cx="8" cy="8" r="0.7" fill="black" />
      </mask>
      <path d={GLYPH_TILE} fill="currentColor" mask={`url(#${mask})`} />
    </svg>
  )
}
