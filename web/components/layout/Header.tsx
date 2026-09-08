import Image from "next/image";
import Link from "next/link";

/**
 * Minimal shared top bar for the public site (landing + buscar). Server
 * Component — no interactivity needed.
 */
export function Header() {
  return (
    <header className="flex-none border-b border-border bg-surface/80 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-6">
        <Link href="/" aria-label="Fudo">
          {/* Real wordmark from the design reference (dark-theme lockup),
              not a generic text substitute — matches the app's dark-only
              palette exactly. */}
          <Image
            src="/fudo-logo.png"
            alt="Fudo"
            width={200}
            height={50}
            priority
            className="h-5 w-auto"
          />
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
