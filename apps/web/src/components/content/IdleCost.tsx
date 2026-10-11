import { WindowSection } from './AppWindow'

// Measured with the dropdown and main window closed, see README
const FIGURES = [
  { value: '76', unit: 'MB of memory' },
  { value: '0.5', unit: '% of one core' },
]

export function IdleCost() {
  return (
    <WindowSection title="Light when you’re not looking">
      <p className="max-w-[34em] text-secondary">
        The expensive work, like walking the process list or reading fans and sensors, only runs while a view needs
        it. With the dropdown closed, MacStats sits around
      </p>
      <p className="mt-7 flex flex-wrap gap-14">
        {FIGURES.map(({ value, unit }) => (
          <span key={unit} className="flex items-baseline gap-2.5">
            <b className="text-[clamp(3.5rem,9vw,6rem)] leading-none font-bold tracking-[-0.04em] tabular-nums">
              {value}
            </b>
            {unit}
          </span>
        ))}
      </p>
    </WindowSection>
  )
}
