"use client";

import { useSession } from "@/lib/session/use-session";
import { Card } from "@/components/ui/Card";
import type { VisitTier } from "@/lib/types";

export interface ProfileHeaderProps {
  topTier: VisitTier;
}

/**
 * Consumer identity block for /perfil on phone widths (`vw < 900`) — avatar
 * initials, full name, email and the tier badge, mirroring the design
 * reference's `loggedIn` header row exactly (`docs/design-reference/Fudo
 * App.dc.html`, lines ~678-685): the tier badge sits at the same level as
 * name/email, right-aligned — not in its own row below them (see
 * `docs/visual-qa-report.md` section 6, hallazgo #3, now fixed here).
 *
 * DNI/Teléfono and "Actualizar mis datos" used to live in this card, but
 * the design only ever shows them inside the "Ajustes" tab's `dataRows`
 * list (now `SettingsTab.tsx`) — this header stays a pure identity strip,
 * shown above the horizontal Visitas/Favoritos/Ajustes `SegmentedControl`.
 * At `vw >= 900` this and `SegmentedControl` are both replaced by
 * `ProfileSidebar`, which folds identity + a vertical nav into one sticky
 * left rail per the wide design reference (`Fudo Customers.dc.html`,
 * ~lines 792-811) — see PerfilView.tsx.
 */
export function ProfileHeader({ topTier }: ProfileHeaderProps) {
  const { consumer } = useSession();

  if (!consumer) return null;

  const fullName = `${consumer.firstName} ${consumer.lastName}`.trim();
  const initials = `${consumer.firstName[0] ?? ""}${consumer.lastName[0] ?? ""}`.toUpperCase();

  return (
    <Card className="flex items-center gap-3.5 p-4">
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
      <span className="flex-none rounded-full bg-accent-soft px-2.5 py-1 text-[11px] font-bold text-accent">
        {topTier}
      </span>
    </Card>
  );
}
