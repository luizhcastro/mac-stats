import { useLatestDmgUrl } from '../hooks/useLatestDmgUrl'

/** `source` tells the hero button apart from other download links in analytics */
export function DownloadButton({ source = 'hero' }: { source?: string }) {
  const href = useLatestDmgUrl()

  return (
    <a href={href} data-umami-event="Download" data-umami-event-source={source} className="button">
      Download for macOS
    </a>
  )
}
