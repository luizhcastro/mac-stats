import type { LiveStats } from '../../hooks/useLiveStats'
import type { BarMetric } from '../../lib/metrics'
import { DownloadButton } from '../DownloadButton'
import { StatusItems } from '../menubar/MenuBar'

type InstallProps = { stats: LiveStats; visible: Set<BarMetric> }

/** Three steps, each with what you do and what you see; the last one ends in the menu bar */
export function Install({ stats, visible }: InstallProps) {
  return (
    <section id="install" aria-labelledby="install-title" className="page scroll-mt-16 pt-[clamp(6rem,14vw,12rem)]">
      <div className="lg:pl-[25%]">
        <h2 id="install-title" className="enter text-head leading-none font-bold tracking-[-0.035em]">
          Install
        </h2>

        <ol className="mt-14 grid max-w-[35rem] gap-[clamp(4rem,7vw,5.5rem)]">
          <li>
            <p className="enter text-lead leading-tight font-semibold">First, download the disk image.</p>
            <div className="enter mt-5 flex flex-wrap items-center gap-x-6 gap-y-3 rounded-2xl bg-surface p-5">
              <DownloadButton source="install" />
              <span className="text-small text-muted">Signed and notarized, from GitHub releases.</span>
            </div>
          </li>

          <li>
            <p className="enter text-lead leading-tight font-semibold">Then drag MacStats into Applications.</p>
            <div data-ui className="enter mt-5 flex items-center justify-center gap-10 rounded-2xl bg-surface px-5 py-8 text-[13px] text-label">
              <figure className="grid justify-items-center gap-2">
                <img src="/icon.png" alt="" className="size-16" />
                <figcaption>MacStats</figcaption>
              </figure>
              <svg viewBox="0 0 40 12" className="w-14 fill-none stroke-secondary stroke-[1.5]" aria-hidden="true">
                <path d="M1 6h36M32 1.5 37.5 6 32 10.5" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              <figure className="grid justify-items-center gap-2">
                <FolderIcon />
                <figcaption>Applications</figcaption>
              </figure>
            </div>
          </li>

          <li>
            <p className="enter text-lead leading-tight font-semibold">Open it. MacStats moves into your menu bar.</p>
            <p className="enter mt-3">macOS asks once whether to open an app from the internet. Choose Open.</p>
            <div className="enter mt-6 flex justify-end rounded-tl-[72px] bg-stage py-12 pr-4 pl-10 xl:w-[47.5rem]">
              <div data-ui className="glass glass-dark flex h-[30px] items-center rounded-lg px-3 text-[13px] text-label">
                <StatusItems stats={stats} visible={visible} />
              </div>
            </div>
          </li>
        </ol>
      </div>
    </section>
  )
}

/** The blue macOS folder with the Applications glyph, drawn flat */
function FolderIcon() {
  return (
    <svg viewBox="0 0 64 64" className="size-16" aria-hidden="true">
      <path d="M6 16a4 4 0 0 1 4-4h14l5 5h25a4 4 0 0 1 4 4v29a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4Z" fill="#3a8ee6" />
      <path d="M6 23a4 4 0 0 1 4-4h44a4 4 0 0 1 4 4v27a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4Z" fill="#62adf5" />
      <path d="M26 46 32 30l6 16M28.2 40.5h7.6" fill="none" stroke="#2f7fd3" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
