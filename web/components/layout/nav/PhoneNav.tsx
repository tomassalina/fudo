"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSession } from "@/lib/session/use-session";
import { Sheet } from "@/components/ui/Sheet";
import { cn } from "@/lib/utils/cn";
import { NAV_LEFT, visibleNavRight, type NavItemDef } from "./nav-items";
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

/**
 * Floating bottom pill nav for phone widths (< 900px) — see
 * `docs/design-reference/Fudo App.dc.html`'s bottom nav and
 * `mobile/lib/shared/widgets/main_shell.dart`'s `_FloatingBottomNav` for the
 * raised central QR action this mirrors. Positioned `fixed`, so it floats
 * over page content rather than reserving layout space (same intent as the
 * Flutter shell's `extendBody: true`).
 */
export function PhoneNav() {
  const pathname = usePathname();
  const { isAuthenticated } = useSession();
  const [qrOpen, setQrOpen] = useState(false);
  const navRight = visibleNavRight(isAuthenticated);

  return (
    <>
      <nav className="fixed inset-x-0 bottom-6 z-30 flex justify-center px-5">
        <div className="relative flex items-center gap-0.5 rounded-full border border-border bg-nav p-1.5 shadow-nav backdrop-blur-md">
          {NAV_LEFT.map((item) => (
            <TabLink
              key={item.key}
              item={item}
              active={isActiveHref(pathname, item.href)}
            />
          ))}

          {/* Reserves room for the QR button, which overlaps this pill —
              see the absolutely-positioned button below. */}
          <span className="w-11" aria-hidden />

          {navRight.map((item) => (
            <TabLink
              key={item.key}
              item={item}
              active={isActiveHref(pathname, item.href)}
            />
          ))}

          <button
            type="button"
            onClick={() => setQrOpen(true)}
            aria-label="Mi código QR"
            className="absolute left-1/2 top-1/2 flex h-15 w-15 -translate-x-1/2 -translate-y-[58%] items-center justify-center rounded-full bg-gradient-to-b from-cta-from to-cta-to shadow-qr transition-transform duration-200 active:scale-95"
          >
            <span className="material-symbols text-2xl text-white">
              qr_code_scanner
            </span>
          </button>
        </div>
      </nav>

      <Sheet open={qrOpen} onClose={() => setQrOpen(false)} title="Tu código Fudo">
        <p className="text-[13.5px] text-foreground-muted">
          Mostrale este código al mesero para validar tu visita.
        </p>
      </Sheet>
    </>
  );
}
