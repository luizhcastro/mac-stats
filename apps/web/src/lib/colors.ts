/** macOS dark-mode system colors the app's charts use (.blue, .green, .orange, .purple, .pink) */
export const SYSTEM_COLORS = {
  blue: '#0a84ff',
  green: '#30d158',
  orange: '#ff9f0a',
  purple: '#bf5af2',
  pink: '#ff375f',
  yellow: '#ffd60a',
  red: '#ff453a',
} as const

/** Same thresholds as TemperaturePane.color(for:) */
export function temperatureColor(celsius: number): string {
  if (celsius >= 90) return SYSTEM_COLORS.red
  if (celsius >= 75) return SYSTEM_COLORS.orange
  if (celsius >= 60) return SYSTEM_COLORS.yellow
  return SYSTEM_COLORS.green
}
