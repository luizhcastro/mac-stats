import { Icon, type IconName } from '../Icon'
import { TrafficLights } from '../TrafficLights'

/** Mirrors `SidebarSection` in MainWindowView.swift */
export type SidebarSection =
  | 'overview'
  | 'cpu'
  | 'gpu'
  | 'memory'
  | 'disk'
  | 'network'
  | 'battery'
  | 'temperature'
  | 'fans'
  | 'processes'
  | 'settings'

type Item = { id: SidebarSection; title: string; icon: IconName }

const GROUPS: { heading?: string; items: Item[] }[] = [
  { items: [{ id: 'overview', title: 'Overview', icon: 'grid' }] },
  {
    heading: 'Hardware',
    items: [
      { id: 'cpu', title: 'CPU', icon: 'cpu' },
      { id: 'gpu', title: 'GPU', icon: 'display' },
      { id: 'memory', title: 'Memory', icon: 'memorychip' },
      { id: 'disk', title: 'Disk', icon: 'internaldrive' },
      { id: 'network', title: 'Network', icon: 'network' },
      { id: 'battery', title: 'Battery', icon: 'battery' },
      { id: 'temperature', title: 'Temperature', icon: 'thermometer' },
      { id: 'fans', title: 'Fans', icon: 'fan' },
    ],
  },
  { heading: 'Activity', items: [{ id: 'processes', title: 'Processes', icon: 'list' }] },
  { items: [{ id: 'settings', title: 'Settings', icon: 'gear' }] },
]

export const SECTION_TITLES = Object.fromEntries(
  GROUPS.flatMap((g) => g.items).map((item) => [item.id, item.title]),
) as Record<SidebarSection, string>

type SidebarProps = { selection: SidebarSection; onSelect: (section: SidebarSection) => void }

/** Floating glass sidebar, as macOS 26 draws NavigationSplitView's sidebar */
export function Sidebar({ selection, onSelect }: SidebarProps) {
  return (
    <nav aria-label="MacStats sections" className="glass flex w-[200px] flex-none flex-col rounded-[18px] p-2.5 max-md:hidden">
      <div className="mb-3 flex items-center justify-between px-1.5 pt-1">
        <TrafficLights />
        <Icon name="sidebar" className="size-4 text-secondary" />
      </div>

      {GROUPS.map((group, i) => (
        <div key={i} className="mb-3">
          {group.heading && <div className="mb-1 px-2 text-[11px] font-semibold text-tertiary">{group.heading}</div>}
          {group.items.map((item) => (
            <SidebarRow key={item.id} item={item} selected={item.id === selection} onSelect={onSelect} />
          ))}
        </div>
      ))}
    </nav>
  )
}

function SidebarRow({ item, selected, onSelect }: { item: Item; selected: boolean; onSelect: (s: SidebarSection) => void }) {
  return (
    <button
      type="button"
      aria-current={selected ? 'page' : undefined}
      onClick={() => onSelect(item.id)}
      className={`flex w-full cursor-pointer items-center gap-2 rounded-lg px-2 py-[5px] text-left text-[13px] ${
        selected ? 'bg-accent font-medium text-on-accent' : 'hover:bg-white/8'
      }`}
    >
      <Icon name={item.icon} className={`size-4 ${selected ? '' : 'text-secondary'}`} />
      {item.title}
    </button>
  )
}

/** On narrow screens the sidebar collapses into a scrollable row of pills above the pane */
export function CompactSidebar({ selection, onSelect }: SidebarProps) {
  return (
    <div className="flex gap-1.5 overflow-x-auto border-b border-separator px-4 py-2.5 md:hidden">
      {GROUPS.flatMap((g) => g.items).map((item) => (
        <button
          key={item.id}
          type="button"
          onClick={() => onSelect(item.id)}
          className={`flex flex-none cursor-pointer items-center gap-1.5 rounded-full px-3 py-1 text-[13px] ${
            item.id === selection ? 'bg-accent text-on-accent' : 'bg-white/8'
          }`}
        >
          <Icon name={item.icon} className="size-3.5" />
          {item.title}
        </button>
      ))}
    </div>
  )
}
