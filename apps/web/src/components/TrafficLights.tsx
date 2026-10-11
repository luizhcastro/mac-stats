/** The red / yellow / green window buttons */
export function TrafficLights() {
  return (
    <div className="flex gap-2" aria-hidden="true">
      {['bg-[#ff5f57]', 'bg-[#febc2e]', 'bg-[#28c840]'].map((color) => (
        <i key={color} className={`size-3 rounded-full shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.2)] ${color}`} />
      ))}
    </div>
  )
}
