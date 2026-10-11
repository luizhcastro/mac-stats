import { useEffect, useState } from 'react'

function formatClock(date: Date): string {
  const day = date.toLocaleDateString('en-US', { weekday: 'short' })
  const dayMonth = date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })
  const time = date.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })
  return `${day} ${dayMonth} ${time}`
}

export function Clock() {
  const [now, setNow] = useState(() => new Date())

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 10_000)
    return () => clearInterval(timer)
  }, [])

  return <span className="ml-2.5 whitespace-nowrap tabular-nums max-sm:hidden">{formatClock(now)}</span>
}
