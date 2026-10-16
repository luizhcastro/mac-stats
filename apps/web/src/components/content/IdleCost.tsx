import { useState } from 'react'

// Measured with the dropdown and main window closed, see README
const IDLE_CPU_SHARE = 0.005
const IDLE_MEMORY_MB = 76

/** What MacStats costs a day while nobody is looking: the visitor sets the hours */
export function IdleCost() {
  const [hours, setHours] = useState(9)
  const minutes = (hours * 60 * IDLE_CPU_SHARE).toFixed(1)

  return (
    <section aria-labelledby="idle-title" className="mt-[clamp(6rem,14vw,12rem)] bg-surface">
      <div className="page flex min-h-[88svh] flex-col py-[clamp(4rem,8vw,7rem)] max-md:min-h-[84svh]">
        <h2 id="idle-title" className="enter text-head leading-none font-bold tracking-[-0.035em]">
          How long is your Mac awake?
        </h2>

        <label data-ui className="enter mt-8 grid max-w-[25rem] gap-2 text-[13px] text-label">
          <span className="flex justify-between">
            Hours awake per day
            <span className="text-secondary tabular-nums">{hours} h</span>
          </span>
          <input
            type="range"
            min={1}
            max={24}
            value={hours}
            onChange={(e) => setHours(Number(e.target.value))}
            className="h-11 w-full cursor-pointer accent-white"
          />
        </label>

        <div className="mt-auto grid items-end gap-x-12 gap-y-6 pt-16 md:grid-cols-[1fr_minmax(0,22rem)]">
          <p className="enter text-[clamp(8.75rem,19vw,20rem)] leading-[0.8] font-extrabold tracking-[-0.05em] tabular-nums max-md:text-[30vw]">
            {minutes}
            <span className="ml-[0.08em] text-[0.22em] tracking-[-0.02em]">min</span>
          </p>
          <p className="enter late md:pb-3">
            With its dropdown and window closed, MacStats averages about {IDLE_CPU_SHARE * 100}% of one core and{' '}
            {IDLE_MEMORY_MB} MB of memory. Over {hours} hours that adds up to {minutes} minutes of one core’s time.
          </p>
        </div>
      </div>
    </section>
  )
}
