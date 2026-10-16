import { useState } from 'react'
import { Desktop } from './components/Desktop'
import { Features } from './components/content/Features'
import { Footer } from './components/content/Footer'
import { IdleCost } from './components/content/IdleCost'
import { Install } from './components/content/Install'
import { MainWindow } from './components/window/MainWindow'
import { useLiveStats } from './hooks/useLiveStats'
import { BAR_METRICS, type BarMetric } from './lib/metrics'
import { useMixer } from './lib/mixer'

export function App() {
  // Shared by the menu bar replica, its dropdown, the main window replica and the feature
  // fragments, so all of them show the same numbers and the same menu bar selection.
  const stats = useLiveStats()
  const mixer = useMixer()
  const [visibleMetrics, setVisibleMetrics] = useState(() => new Set(BAR_METRICS.map((m) => m.id)))

  function toggleMetric(metric: BarMetric) {
    setVisibleMetrics((current) => {
      const next = new Set(current)
      if (next.has(metric)) next.delete(metric)
      else next.add(metric)
      return next
    })
  }

  return (
    <>
      <main>
        <Desktop stats={stats} mixer={mixer} visible={visibleMetrics} />
        <MainWindow stats={stats} mixer={mixer} visible={visibleMetrics} onToggleMetric={toggleMetric} />
        <Features stats={stats} mixer={mixer} visible={visibleMetrics} onToggleMetric={toggleMetric} />
        <IdleCost />
        <Install stats={stats} visible={visibleMetrics} />
      </main>
      <Footer />
    </>
  )
}
