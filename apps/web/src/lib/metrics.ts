import type { IconName } from '../components/Icon'

/** Mirrors `BarMetric` in apps/macos/Sources/MacStats/DisplayPreferences.swift */
export type BarMetric = 'cpu' | 'temperature' | 'ram' | 'disk' | 'network' | 'appIcon'

/** Tabs of the top processes picker, from TopProcessesView.swift */
export type ProcessTab = 'cpu' | 'ram' | 'disk' | 'net' | 'energy'

export const BAR_METRICS: { id: BarMetric; label: string; icon: IconName }[] = [
  { id: 'cpu', label: 'CPU', icon: 'cpu' },
  { id: 'temperature', label: 'Temp', icon: 'thermometer' },
  { id: 'ram', label: 'RAM', icon: 'memorychip' },
  { id: 'disk', label: 'Disk', icon: 'internaldrive' },
  { id: 'network', label: 'Network', icon: 'network' },
  { id: 'appIcon', label: 'App icon', icon: 'app' },
]

export const PROCESS_TABS: { id: ProcessTab; label: string }[] = [
  { id: 'cpu', label: 'CPU' },
  { id: 'ram', label: 'RAM' },
  { id: 'disk', label: 'Disk' },
  { id: 'net', label: 'Net' },
  { id: 'energy', label: 'Energy' },
]

/** Which process tab the dropdown opens on when a menu bar item is clicked */
export const TAB_FOR_METRIC: Record<BarMetric, ProcessTab> = {
  cpu: 'cpu',
  temperature: 'cpu',
  appIcon: 'cpu',
  ram: 'ram',
  disk: 'disk',
  network: 'net',
}
