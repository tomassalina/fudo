"use client";

import Link from "next/link";
import { useState } from "react";
import { useSession } from "@/lib/session/use-session";
import { cn } from "@/lib/utils/cn";
import { QrMyCodeTab } from "./QrMyCodeTab";
import { QrScanTab } from "./QrScanTab";

type QrTab = "mine" | "scan";

/**
 * Content for the shared `<Sheet>` opened from AppNav (PhoneNav's floating
 * QR button, WideNav's "Mi código" button) — the tab switcher plus each
 * tab's body, matching `qrOpen`/`qrTab` in both design references. The
 * `<Sheet>` itself already renders the "Tu código Fudo" title + close
 * button, so this starts at the "Mi QR" / "Escanear" pill.
 *
 * `isAuthenticated` is guarded here too, not just at the call site: WideNav
 * already hides its QR trigger while logged out (swapped for an "Iniciar
 * sesión" link), and PhoneNav's floating button redirects to /login instead
 * of opening this sheet (see PhoneNav.tsx) — mirroring the phone design
 * reference's `openQr` exactly. This fallback only matters if that guard is
 * ever bypassed; a personal QR genuinely has nothing to show for a guest
 * (unlike the wide reference's "Invitada Fudo" placeholder, which this
 * intentionally does not copy — a fake code for a logged-out visitor reads
 * as broken, not friendly).
 */
export function QrSheetContent() {
  const { isAuthenticated } = useSession();
  const [tab, setTab] = useState<QrTab>("scan");

  if (!isAuthenticated) {
    return (
      <div className="flex flex-col items-center gap-3 py-6 text-center">
        <span aria-hidden className="material-symbols text-[30px] text-foreground-faint">
          qr_code_2
        </span>
        <p className="max-w-[240px] text-[14px] leading-relaxed text-foreground-muted">
          Iniciá sesión para ver tu código y sumar visitas.
        </p>
        <Link
          href="/login"
          className="rounded-full bg-gradient-to-b from-cta-from to-cta-to px-5 py-2.5 text-[13.5px] font-semibold text-white shadow-cta"
        >
          Iniciar sesión
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col">
      <div role="tablist" aria-label="Código QR" className="flex gap-1 rounded-full border border-border bg-surface p-1">
        <button
          type="button"
          role="tab"
          id="qr-tab-mine"
          aria-selected={tab === "mine"}
          aria-controls="qr-tabpanel-mine"
          onClick={() => setTab("mine")}
          className={cn(
            "flex flex-1 items-center justify-center gap-1.5 rounded-full py-3 text-[14px] font-semibold transition-colors duration-200",
            tab === "mine"
              ? "bg-surface-2 text-foreground shadow-[inset_0_1px_0_var(--highlight)]"
              : "text-foreground-faint",
          )}
        >
          <span aria-hidden className="material-symbols text-[18px]">
            qr_code_2
          </span>
          Mi QR
        </button>
        <button
          type="button"
          role="tab"
          id="qr-tab-scan"
          aria-selected={tab === "scan"}
          aria-controls="qr-tabpanel-scan"
          onClick={() => setTab("scan")}
          className={cn(
            "flex flex-1 items-center justify-center gap-1.5 rounded-full py-3 text-[14px] font-semibold transition-colors duration-200",
            tab === "scan"
              ? "bg-surface-2 text-foreground shadow-[inset_0_1px_0_var(--highlight)]"
              : "text-foreground-faint",
          )}
        >
          <span aria-hidden className="material-symbols text-[18px]">
            qr_code_scanner
          </span>
          Escanear
        </button>
      </div>

      {tab === "mine" ? (
        <div role="tabpanel" id="qr-tabpanel-mine" aria-labelledby="qr-tab-mine">
          <QrMyCodeTab />
        </div>
      ) : (
        <div role="tabpanel" id="qr-tabpanel-scan" aria-labelledby="qr-tab-scan">
          <QrScanTab />
        </div>
      )}
    </div>
  );
}
