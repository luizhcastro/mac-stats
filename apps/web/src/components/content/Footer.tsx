import { ISSUES_URL, REPO_URL } from '../../lib/links'

export function Footer() {
  return (
    <footer className="mx-auto flex max-w-[1080px] flex-wrap gap-6 px-5 pt-10 pb-12 text-[0.9rem] text-secondary">
      <span className="mr-auto">MacStats is MIT licensed.</span>
      <a href={REPO_URL} className="underline">
        GitHub
      </a>
      <a href={ISSUES_URL} className="underline">
        Report an issue
      </a>
    </footer>
  )
}
