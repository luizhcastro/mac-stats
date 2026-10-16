import { ISSUES_URL, RELEASES_URL, REPO_URL } from '../../lib/links'

/** One quiet line at the bottom: what this is, a few links, the licence */
export function Footer() {
  return (
    <footer className="page grid gap-2 pt-[min(20svh,12rem)] pb-8 text-small text-muted md:grid-cols-[1fr_auto_1fr] md:items-baseline">
      <span>MacStats, a menu bar system monitor</span>
      <nav aria-label="Project" className="flex flex-wrap gap-x-6 gap-y-2 text-ink">
        <a href={REPO_URL} data-umami-event="View source" data-umami-event-source="footer" className="link">
          GitHub
        </a>
        <a href={RELEASES_URL} className="link">
          Releases
        </a>
        <a href={ISSUES_URL} data-umami-event="Report an issue" className="link">
          Report an issue
        </a>
      </nav>
      <span className="md:text-right">MIT licence · 2026</span>
    </footer>
  )
}
