"use client";

import { useSession } from "@/lib/session/use-session";
import { Card } from "@/components/ui/Card";
import { cn } from "@/lib/utils/cn";
import type { SegmentedOption } from "@/components/ui/SegmentedControl";
import type { VisitTier } from "@/lib/types";

export interface ProfileSidebarProps<T extends string> {
  topTier: VisitTier;
  options: SegmentedOption<T>[];
  value: T;
  onChange: (key: T) => void;
}

/**
 * Wide-only (`vw >= 900`) left rail for /perfil: one sticky `Card` holding
 * the identity block (avatar, name, email, tier badge) with the section nav
 * — Visitas/Favoritos/Ajustes — as a vertical list of rows underneath,
 * active row highlighted with `bg-surface-2`. Mirrors the design reference's
 * wide `loggedIn` panel exactly (`docs/design-reference/Fudo
 * Customers.dc.html`, ~lines 792-811: `pTabs`' `bg`/`ink`/`sh` derivation at
 * ~line 1898). Below 900px this collapses into `ProfileHeader` (identity
 * only, its own card) plus the horizontal pill `SegmentedControl` — see
 * PerfilView.tsx, which renders exactly one of the two per viewport.
 *
 * Same `role="tablist"`/`"tab"`/`aria-controls` wiring as `SegmentedControl`
 * (down to reusing its `segmented-tab-{key}` id scheme) so the tabpanels in
 * PerfilView stay correctly labelled regardless of which nav is mounted.
 */
export function ProfileSidebar<T extends string>({
  topTier,
  options,
  value,
  onChange,
}: ProfileSidebarProps<T>) {
  const { consumer } = useSession();

  if (!consumer) return null;

  const fullName = `${consumer.firstName} ${consumer.lastName}`.trim();
  const initials = `${consumer.firstName[0] ?? ""}${consumer.lastName[0] ?? ""}`.toUpperCase();

  return (
    <Card as="aside" className="sticky top-24 flex flex-col gap-3 self-start p-5">
      <div className="flex items-center gap-3.5">
        <div className="flex h-14 w-14 flex-none items-center justify-center rounded-full bg-accent-soft">
          <span className="font-heading text-xl font-black text-accent">{initials}</span>
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate font-heading text-xl font-extrabold text-foreground">
            {fullName}
          </p>
          <p className="truncate text-[12.5px] text-foreground-muted">{consumer.email}</p>
        </div>
      </div>

      <span className="w-fit flex-none rounded-full bg-accent-soft px-2.5 py-1 text-[11px] font-bold text-accent">
        {topTier}
      </span>

      <div
        role="tablist"
        aria-label="Secciones de tu perfil"
        aria-orientation="vertical"
        className="flex flex-col gap-1.5 pt-1"
      >
        {options.map((option) => {
          const active = option.key === value;
          return (
            <button
              key={option.key}
              type="button"
              role="tab"
              id={`segmented-tab-${option.key}`}
              aria-selected={active}
              aria-controls={`segmented-tabpanel-${option.key}`}
              onClick={() => onChange(option.key)}
              className={cn(
                "flex items-center gap-2.5 rounded-[14px] px-3.5 py-3 text-left text-[14px] font-semibold transition-colors duration-200",
                active
                  ? "bg-surface-2 text-foreground shadow-[inset_0_1px_0_var(--highlight),0_2px_8px_rgba(0,0,0,0.18)]"
                  : "text-foreground-faint hover:text-foreground",
              )}
            >
              <span aria-hidden className="material-symbols text-[19px]">
                {option.icon}
              </span>
              {option.label}
            </button>
          );
        })}
      </div>
    </Card>
  );
}
