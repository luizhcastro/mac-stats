import { useEffect, useState } from 'react'
import { LATEST_RELEASE_API, RELEASES_URL } from '../lib/links'

type Release = { assets: { name: string; browser_download_url: string }[] }

// One request per page load, shared by every component that needs the link
let latestDmg: Promise<string | undefined> | undefined

function fetchLatestDmg(): Promise<string | undefined> {
  latestDmg ??= fetch(LATEST_RELEASE_API)
    .then((res) => (res.ok ? (res.json() as Promise<Release>) : Promise.reject(res.status)))
    .then((release) => release.assets.find((asset) => asset.name.endsWith('.dmg'))?.browser_download_url)
    .catch(() => undefined)
  return latestDmg
}

/**
 * Direct download URL of the newest release's .dmg. The asset name carries the version
 * (MacStats-0.4.0.dmg), so it's resolved through the GitHub API on load. Until that
 * resolves, or if it fails (offline, rate limit), it falls back to the releases page.
 */
export function useLatestDmgUrl(): string {
  const [url, setUrl] = useState(RELEASES_URL)

  useEffect(() => {
    let active = true
    fetchLatestDmg().then((dmg) => {
      if (active && dmg) setUrl(dmg)
    })
    return () => {
      active = false
    }
  }, [])

  return url
}
