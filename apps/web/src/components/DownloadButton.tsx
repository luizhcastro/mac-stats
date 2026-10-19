import type { ReactNode } from 'react'
import { useLatestDmgUrl } from '../hooks/useLatestDmgUrl'

type DownloadButtonProps = {
  /** Tells the hero button apart from other download links in analytics */
  source?: string
  className?: string
  children?: ReactNode
}

export function DownloadButton({ source = 'hero', className = '', children = 'Download for macOS' }: DownloadButtonProps) {
  const href = useLatestDmgUrl()

  return (
    <a href={href} data-umami-event="Download" data-umami-event-source={source} className={`button ${className}`}>
      {children}
    </a>
  )
}
