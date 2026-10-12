import { useState, type ReactNode } from 'react'
import type { LiveStats } from '../../hooks/useLiveStats'
import type { HistoryRange } from '../../lib/history'
import { MAIN_WINDOW_ID } from '../../lib/links'
import type { BarMetric } from '../../lib/metrics'
import type { Mixer } from '../../lib/mixer'
import { TrafficLights } from '../TrafficLights'
import { BatteryPane } from './panes/BatteryPane'
import { CpuPane } from './panes/CpuPane'
import { DiskPane } from './panes/DiskPane'
import { FansPane } from './panes/FansPane'
import { GpuPane } from './panes/GpuPane'
import { MemoryPane } from './panes/MemoryPane'
import { NetworkPane } from './panes/NetworkPane'
import { OverviewPane } from './panes/OverviewPane'
import { ProcessesPane } from './panes/ProcessesPane'
import { SettingsPane } from './panes/SettingsPane'
import { SoundPane } from './panes/SoundPane'
import { TemperaturePane } from './panes/TemperaturePane'
import { CompactSidebar, SECTION_TITLES, Sidebar, type SidebarSection } from './Sidebar'

type MainWindowProps = {
  stats: LiveStats
  mixer: Mixer
  visible: Set<BarMetric>
  onToggleMetric: (metric: BarMetric) => void
}

/** Interactive replica of the MacStats main window (MainWindowView.swift) */
export function MainWindow({ stats, mixer, visible, onToggleMetric }: MainWindowProps) {
  const [selection, setSelection] = useState<SidebarSection>('overview')
  const [range, setRange] = useState<HistoryRange>('minute')

  const rangeProps = { stats, range, onRangeChange: setRange }
  const panes: Record<SidebarSection, ReactNode> = {
    overview: <OverviewPane stats={stats} />,
    cpu: <CpuPane {...rangeProps} />,
    gpu: <GpuPane stats={stats} />,
    memory: <MemoryPane {...rangeProps} />,
    disk: <DiskPane {...rangeProps} />,
    network: <NetworkPane {...rangeProps} />,
    battery: <BatteryPane />,
    temperature: <TemperaturePane {...rangeProps} />,
    fans: <FansPane stats={stats} />,
    processes: <ProcessesPane stats={stats} />,
    sound: <SoundPane mixer={mixer} />,
    settings: <SettingsPane visible={visible} onToggleMetric={onToggleMetric} />,
  }

  return (
    <section
      id={MAIN_WINDOW_ID}
      aria-label="MacStats main window preview"
      className="mx-auto mb-24 scroll-mt-16 w-[calc(100%-2.5rem)] max-w-[1180px]">
      <div className="glass glass-dark flex h-[min(720px,85svh)] overflow-hidden rounded-[26px] p-2 max-md:h-auto max-md:flex-col max-md:p-0">
        <Sidebar selection={selection} onSelect={setSelection} />

        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex h-11 flex-none items-center gap-3 px-6 max-md:px-4">
            <span className="md:hidden">
              <TrafficLights />
            </span>
            <span className="text-[15px] font-semibold">{SECTION_TITLES[selection]}</span>
          </div>
          <CompactSidebar selection={selection} onSelect={setSelection} />
          <div className="min-h-0 flex-1 md:overflow-y-auto">{panes[selection]}</div>
        </div>
      </div>
    </section>
  )
}
