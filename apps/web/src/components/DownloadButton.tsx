import { useLatestDmgUrl } from '../hooks/useLatestDmgUrl'

export function DownloadButton() {
  const href = useLatestDmgUrl()

  return (
    <a
      href={href}
      className="glass rounded-full px-6 py-3.5 font-semibold no-underline [--glass-fill:linear-gradient(rgb(255_255_255/0.3),rgb(255_255_255/0.12))] hover:[--glass-fill:linear-gradient(rgb(255_255_255/0.4),rgb(255_255_255/0.18))]"
    >
      Download free for macOS
    </a>
  )
}
