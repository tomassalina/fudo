"use client";

import { useSession } from "@/lib/session/use-session";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { Card } from "@/components/ui/Card";
import { cn } from "@/lib/utils/cn";
import type { VisitTier } from "@/lib/mock/visit-history";

/**
 * Masks a DNI the way the design reference always shows it ("•••• 4821" —
 * last 4 digits only, never the full number). There is no real DNI capture
 * flow yet (per design.md Decisión 1, a waiter loads it at checkout, not the
 * consumer at signup — see the TODO in session-provider.tsx / RegisterForm's
 * doc comment), so a freshly mocked consumer's `dni` is always `undefined`.
 * That's shown honestly instead of faking a masked value out of nothing.
 */
function formatMaskedDni(dni: string | undefined): string {
  // Short on purpose — this renders in the same narrow, right-aligned value
  // slot as a real masked DNI ("•••• 4821"), so the fallback has to fit
  // there too instead of truncating into an ellipsis.
  if (!dni) return "Pendiente";
  const last4 = dni.replace(/\D/g, "").slice(-4).padStart(4, "•");
  return `•••• ${last4}`;
}

export interface ProfileHeaderProps {
  topTier: VisitTier;
  onEdit: () => void;
}

/**
 * Consumer identity block for /perfil — avatar initials, full name, masked
 * DNI, phone, and the "Actualizar mis datos" edit trigger. Mirrors the
 * `loggedIn` header + the "Nombre"/"Teléfono"/"DNI" rows from `dataRows` in
 * both design references, condensed into one header instead of a separate
 * "DATOS PERSONALES" list — this phase has nothing else to show alongside it
 * (no theme/notification toggles, no account-security rows), so a second
 * card for three read-only fields would be visual overhead without content
 * to justify it.
 */
export function ProfileHeader({ topTier, onEdit }: ProfileHeaderProps) {
  const { consumer } = useSession();
  const isPhone = useIsPhoneViewport();

  if (!consumer) return null;

  const fullName = `${consumer.firstName} ${consumer.lastName}`.trim();
  const initials = `${consumer.firstName[0] ?? ""}${consumer.lastName[0] ?? ""}`.toUpperCase();

  return (
    <Card
      className={cn(
        "flex flex-col gap-4",
        isPhone ? "p-4" : "sticky top-24 p-5",
      )}
    >
      <div className="flex items-center gap-3.5">
        <div className="flex h-14 w-14 flex-none items-center justify-center rounded-full bg-accent-soft">
          <span className="font-heading text-xl font-black text-accent">
            {initials}
          </span>
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate font-heading text-xl font-extrabold text-foreground">
            {fullName}
          </p>
          <p className="truncate text-[12.5px] text-foreground-muted">
            {consumer.email}
          </p>
        </div>
      </div>

      <span className="w-fit rounded-full bg-accent-soft px-2.5 py-1 text-[11px] font-bold text-accent">
        {topTier}
      </span>

      <div className="flex flex-col gap-0 rounded-[16px] border border-border bg-background/40 p-1">
        <div className="flex items-center gap-2.5 border-b border-border px-3 py-3">
          <span aria-hidden className="material-symbols text-[19px] text-foreground-faint">
            fingerprint
          </span>
          <span className="flex-none text-[13.5px] text-foreground-muted">DNI</span>
          <span className="flex-1 truncate text-right text-[13.5px] text-foreground">
            {formatMaskedDni(consumer.dni)}
          </span>
        </div>
        <div className="flex items-center gap-2.5 px-3 py-3">
          <span aria-hidden className="material-symbols text-[19px] text-foreground-faint">
            call
          </span>
          <span className="flex-none text-[13.5px] text-foreground-muted">Teléfono</span>
          <span className="flex-1 truncate text-right text-[13.5px] text-foreground">
            {consumer.phone || "Sin cargar"}
          </span>
        </div>
      </div>

      <button
        type="button"
        onClick={onEdit}
        className="flex w-full items-center gap-2.5 rounded-full border border-border bg-surface px-4 py-3 text-left transition-colors hover:border-accent/50"
      >
        <span aria-hidden className="material-symbols text-[18px] text-accent">
          edit
        </span>
        <span className="flex-1 text-[13.5px] font-semibold text-foreground">
          Actualizar mis datos
        </span>
        <span aria-hidden className="material-symbols text-[18px] text-foreground-faint">
          chevron_right
        </span>
      </button>
    </Card>
  );
}
