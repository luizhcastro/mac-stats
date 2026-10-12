import { WindowSection } from './AppWindow'

const FEATURES = [
  {
    title: 'Menu bar',
    body: 'Pick any of CPU, temperature, RAM, disk and network. Each one is its own item, so a crowded bar drops them one at a time instead of all at once.',
  },
  {
    title: 'Dropdown',
    body: 'Live readouts plus the top processes by CPU, memory, disk, network and energy. It opens on the tab of the metric you clicked, and every section folds away so it stays as short as you like.',
  },
  {
    title: 'Main window',
    body: 'CPU, GPU, memory, disk, network, battery, temperature and fans, each chart switchable between the last minute, hour and day. Plus a full process table you can filter and sort.',
  },
  {
    title: 'Volume mixer',
    body: 'Every app that plays sound gets its own volume slider and mute, like the Windows mixer. MacStats remembers each app and applies it whenever the app plays again. Requires macOS 14.4.',
  },
  {
    title: 'Private',
    body: 'No account, no telemetry, no dependencies. The only network request is the public IP lookup in the Wi-Fi pane.',
  },
]

export function Features() {
  return (
    <WindowSection title="What you get">
      <dl className="grid gap-x-16 gap-y-10 md:grid-cols-2">
        {FEATURES.map(({ title, body }) => (
          <div key={title}>
            <dt className="mb-1 font-semibold">{title}</dt>
            <dd className="max-w-[34em] text-secondary">{body}</dd>
          </div>
        ))}
      </dl>
    </WindowSection>
  )
}
