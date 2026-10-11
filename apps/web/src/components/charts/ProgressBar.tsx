/** Linear ProgressView: a thin track with a filled portion (0–100), tinted with the system accent (blue) */
export function ProgressBar({ value, color = 'bg-[#0a84ff]' }: { value: number; color?: string }) {
  return (
    <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
      <div
        className={`h-full rounded-full transition-[width] duration-600 motion-reduce:transition-none ${color}`}
        style={{ width: `${Math.min(100, Math.max(0, value))}%` }}
      />
    </div>
  )
}
