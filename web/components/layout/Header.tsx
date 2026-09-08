import Link from "next/link";

/**
 * Minimal shared top bar for the public site (landing + buscar). Server
 * Component — no interactivity needed.
 */
export function Header() {
  return (
    <header className="flex-none border-b border-border bg-surface/80 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-6">
        <Link
          href="/"
          className="font-heading text-lg font-black tracking-tight text-foreground"
        >
          Fudo<span className="text-accent">.</span>
        </Link>
        <Link
          href="/buscar"
          className="text-sm font-semibold text-foreground-muted transition-colors hover:text-foreground"
        >
          Buscar
        </Link>
      </div>
    </header>
  );
}
