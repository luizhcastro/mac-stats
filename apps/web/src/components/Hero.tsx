import { REPO_URL } from '../lib/links'
import { DownloadButton } from './DownloadButton'

export function Hero() {
  return (
    <section className="pt-32 max-desk:pt-16">
      <img
        src="/icon.png"
        alt="MacStats icon"
        className="mb-8 size-28 max-sm:mb-6 max-sm:size-20 drop-shadow-[0_18px_30px_rgb(0_0_0/0.5)]"
      />
      <h1 className="max-w-[11ch] text-[clamp(2.8rem,6.5vw,5.4rem)] leading-[1.02] font-bold tracking-[-0.035em]">
        Your Mac’s vitals, one glance away.
      </h1>
      <p className="mt-6 mb-9 max-w-[32em] text-[1.2rem] text-secondary">
        MacStats puts CPU, temperature, memory, disk and network in the menu bar. Click any of them to see which
        apps are using it, without opening Activity Monitor. Free, with no account and no ads.
      </p>

      <div className="flex flex-wrap items-center gap-6">
        <DownloadButton />
        <a href={REPO_URL} data-umami-event="View source" data-umami-event-source="hero" className="text-secondary underline underline-offset-4 hover:text-label">
          View source on GitHub
        </a>
      </div>

      <p className="mt-5 text-sm text-tertiary">Open source (MIT). macOS 13 or later on Apple Silicon.</p>
      <p className="mt-1 text-sm text-tertiary">
        This is a live replica: click the menu bar items or the checkboxes in the dropdown.
      </p>
    </section>
  )
}
