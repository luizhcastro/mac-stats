/**
 * Loads the Umami tracker (https://umami.is) when it's configured in .env.
 * Page views are recorded automatically; clicks on any element with a
 * `data-umami-event` attribute become custom events (Download, Menu bar item, …).
 * `data-domains` keeps localhost and preview deploys out of the stats.
 */
export function loadAnalytics() {
  const { VITE_UMAMI_SCRIPT_URL: src, VITE_UMAMI_WEBSITE_ID: websiteId, VITE_SITE_URL: siteUrl } = import.meta.env
  if (!src || !websiteId) return

  const script = document.createElement('script')
  script.defer = true
  script.src = src
  script.dataset.websiteId = websiteId
  if (siteUrl) script.dataset.domains = new URL(siteUrl).hostname
  document.head.append(script)
}
