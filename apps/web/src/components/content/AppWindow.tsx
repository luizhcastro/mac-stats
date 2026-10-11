import type { ReactNode } from 'react'
import { TrafficLights } from '../TrafficLights'

/** A glass macOS window with traffic lights, used to frame the page content */
export function AppWindow({ title, children }: { title: string; children: ReactNode }) {
  return (
    <main className="glass mx-auto w-[calc(100%-2.5rem)] max-w-[1080px] rounded-[26px] px-[clamp(1.5rem,5vw,4rem)]">
      <div className="-mx-[calc(clamp(1.5rem,5vw,4rem)-18px)] flex h-13 items-center gap-2">
        <TrafficLights />
        <span className="mr-[60px] flex-1 text-center text-[13px] font-semibold text-secondary">{title}</span>
      </div>
      <div className="divide-y divide-separator">{children}</div>
    </main>
  )
}

/** A titled block inside the window */
export function WindowSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="py-16 first:pt-10">
      <h2 className="mb-8 text-[2rem] leading-tight font-bold tracking-[-0.02em]">{title}</h2>
      {children}
    </section>
  )
}
