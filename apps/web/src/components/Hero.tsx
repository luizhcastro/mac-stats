import { REPO_URL } from '../lib/links'
import { order } from '../lib/motion'
import { DownloadButton } from './DownloadButton'

export function Hero() {
  return (
    <section className="pt-24 max-desk:pt-12 desk:max-w-[36rem]">
      <img src="/icon.webp" width={80} height={80} alt="MacStats icon" className="rise mb-8 size-20 max-sm:mb-6 max-sm:size-16" />
      {/* Each line slides up from behind its own baseline */}
      <h1 className="lines text-display leading-[0.95] font-bold tracking-[-0.04em]">
        <span className="line">
          <span style={order(0)}>Your Mac’s vitals,</span>
        </span>
        <span className="line">
          <span style={order(1)}>one glance away.</span>
        </span>
      </h1>
      <p className="rise mt-7 max-w-[30em] text-lead leading-snug" style={order(4)}>
        CPU, temperature, memory, disk and network live in your menu bar. Click one to see which apps are using it.
      </p>

      <div className="rise mt-9 flex flex-wrap items-center gap-x-7 gap-y-4" style={order(5)}>
        <DownloadButton />
        <a href={REPO_URL} data-umami-event="View source" data-umami-event-source="hero" className="link">
          Source on GitHub
        </a>
      </div>

      <p className="rise mt-6 text-small text-muted" style={order(6)}>
        Free and open source (MIT). macOS 13 or later on Apple Silicon.
        <br />
        The dropdown is live: click the menu bar items, section headers and sliders.
      </p>
    </section>
  )
}
