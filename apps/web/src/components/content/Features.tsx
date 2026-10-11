import { WindowSection } from './AppWindow'

const FEATURES = [
  {
    title: 'Menu bar',
    body: 'Pick any of CPU, temperature, RAM, disk and network. Each one is its own item, so a crowded bar drops them one at a time instead of all at once.',
  },
  {
    title: 'Dropdown',
    body: 'Live readouts plus the top processes by CPU, memory, disk, network and energy. It opens on the tab of the metric you clicked.',
  },
  {
    title: 'Main window',
    body: 'CPU, GPU, memory, disk, network, battery, temperature and fans, each chart switchable between the last minute, hour and day. Plus a full process table you can filter and sort.',
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
