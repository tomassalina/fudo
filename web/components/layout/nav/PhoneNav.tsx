"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useSession } from "@/lib/session/use-session";
import { Sheet } from "@/components/ui/Sheet";
import { QrSheetContent } from "@/components/features/perfil/QrSheetContent";
import { cn } from "@/lib/utils/cn";
import { useScrollDirection } from "@/lib/hooks/use-scroll-direction";
import { NAV_LEFT, phoneNavRight, type NavItemDef } from "./nav-items";
import { isActiveHref } from "./is-active-href";

function TabLink({ item, active }: { item: NavItemDef; active: boolean }) {
  return (
    <Link
      href={item.href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex items-center gap-1.5 rounded-full py-2.5 transition-[padding,background-color,box-shadow,color] duration-200",
        active
          ? "bg-gradient-to-b from-cta-from to-cta-to px-4 text-white shadow-cta"
          : "px-3 text-foreground-faint hover:text-foreground",
      )}
    >
      <span className="material-symbols text-[21px]">{item.icon}</span>
      {active ? (
        <span className="whitespace-nowrap text-[13.5px] font-semibold">
          {item.label}
        </span>
      ) : null}
    </Link>
  );
}

/** Same flat, unelevated treatment as {@link TabLink}'s inactive state, for
 * the QR trigger — it's an action button rather than a route, so it never
 * has an `active` pill state of its own. */
function TabButton({
  icon,
  label,
  onClick,
}: {
  icon: string;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="flex items-center gap-1.5 rounded-full px-3 py-2.5 text-foreground-faint transition-colors duration-200 hover:text-foreground"
    >
      <span className="material-symbols text-[21px]">{icon}</span>
    </button>
  );
}

/**
 * Floating bottom pill nav for phone widths (< 900px) — see
 * `docs/design-reference/Fudo App.dc.html`'s bottom nav. All 5 destinations
 * (Inicio, Buscar, QR, Regalar, Perfil/login) sit flat at the same level —
 * an earlier version raised the QR action as a circular FAB for visual
 * consistency with `mobile/lib/shared/widgets/main_shell.dart`'s
 * `_FloatingBottomNav`, but the real reference screenshot has no such
 * elevation, so that treatment was removed. Positioned `fixed`, so it floats
 * over page content rather than reserving layout space (same intent as the
 * Flutter shell's `extendBody: true`).
 */
export function PhoneNav() {
  const pathname = usePathname();
  const router = useRouter();
  const { isAuthenticated } = useSession();
  const [qrOpen, setQrOpen] = useState(false);
  const navRight = phoneNavRight(isAuthenticated);
  const { visible } = useScrollDirection();

  // A logged-out visitor has no personal QR to show — the phone design
  // reference's `openQr` redirects to the profile tab instead of opening
  // this sheet in that case (`Fudo App.dc.html`). Redirecting straight to
  // /login here (rather than /perfil) skips the extra hop, since /perfil
  // itself redirects unauthenticated visitors to /login.
  function handleOpenQr() {
    if (isAuthenticated) {
      setQrOpen(true);
    } else {
      router.push("/login");
    }
  }

  return (
    <>
      <nav
        className={cn(
          "fixed inset-x-0 bottom-6 z-30 flex justify-center px-5 transition-[transform,opacity] duration-300 ease-out",
          visible
            ? "translate-y-0 opacity-100"
            : "pointer-events-none translate-y-24 opacity-0",
        )}
      >
        <div className="flex items-center gap-0.5 rounded-full border border-border bg-nav p-1.5 shadow-nav backdrop-blur-md">
          {NAV_LEFT.map((item) => (
            <TabLink
              key={item.key}
              item={item}
              active={isActiveHref(pathname, item.href)}
            />
          ))}

          <TabButton icon="qr_code_scanner" label="Mi código QR" onClick={handleOpenQr} />

          {navRight.map((item) => (
            <TabLink
              key={item.key}
              item={item}
              active={isActiveHref(pathname, item.href)}
            />
          ))}
        </div>
      </nav>

      <Sheet open={qrOpen} onClose={() => setQrOpen(false)} title="Tu código Fudo">
        <QrSheetContent />
      </Sheet>
    </>
  );
}
