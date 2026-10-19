import { MAIN_WINDOW_ID, REPO_URL } from '../lib/links'
import { DownloadButton } from './DownloadButton'

const SECTIONS = [
  { label: 'Main window', href: `#${MAIN_WINDOW_ID}` },
  { label: 'Features', href: '#features' },
  { label: 'Install', href: '#install' },
]

/** The page's own header, plain on purpose: the macOS replicas start below it */
export function Header() {
  return (
    <header className="sticky top-0 z-40 border-b border-white/8 bg-ground/80 backdrop-blur-lg">
      <div className="page flex h-14 items-center gap-10 text-small">
        <a href="#top" className="flex items-center gap-2.5 text-[15px] font-semibold">
          <img src="/icon.webp" width={24} height={24} alt="" className="size-6" />
          MacStats
        </a>
        <nav aria-label="Page" className="flex gap-7 text-muted max-md:hidden">
          {SECTIONS.map(({ label, href }) => (
            <a key={label} href={href} className="transition-colors duration-200 hover:text-ink">
              {label}
            </a>
          ))}
          <a href={REPO_URL} data-umami-event="View source" data-umami-event-source="header" className="transition-colors duration-200 hover:text-ink">
            GitHub
          </a>
        </nav>
        <DownloadButton source="header" className="ml-auto px-4 py-1.5">
          Download
        </DownloadButton>
      </div>
    </header>
  )
}
