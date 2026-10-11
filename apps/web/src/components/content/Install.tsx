import { useLatestDmgUrl } from '../../hooks/useLatestDmgUrl'
import { WindowSection } from './AppWindow'

export function Install() {
  const dmgUrl = useLatestDmgUrl()

  return (
    <WindowSection title="Install">
      <ol className="max-w-[34em] list-decimal pl-5 text-secondary marker:font-semibold marker:text-label">
        <li className="mb-3 pl-1.5">
          Download the <code className="font-mono text-[0.9em]">.dmg</code> from the{' '}
          <a href={dmgUrl} className="underline">
            latest release
          </a>
          .
        </li>
        <li className="mb-3 pl-1.5">Drag MacStats into Applications.</li>
        <li className="mb-3 pl-1.5">Open it. If macOS blocks the first launch, right-click the app and choose Open.</li>
      </ol>
    </WindowSection>
  )
}
