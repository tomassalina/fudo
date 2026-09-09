"use client";

import { useState } from "react";
import { useSession } from "@/lib/session/use-session";
import { cn } from "@/lib/utils/cn";

// The merchant detail page's `mTabs` toggle — real login-gating on the
// label itself, not just the panel underneath: "Mis visitas" once
// `useSession()` reports a real session, "Recompensas" while logged out
// (exact copy/icon from `docs/design-reference/Fudo App.dc.html`'s `mTabs`:
// `st.user ? "Mis visitas" : "Recompensas"`, icon `workspace_premium`).
export function DetailTabs({
  loyaltySection,
  menuSection,
  fitWidth = false,
}: {
  loyaltySection: React.ReactNode;
  menuSection: React.ReactNode;
  /** The wide `isDetail` branch (Fudo Customers.dc.html) sizes the pill bar
   * to `width: fit-content` with fixed-padding buttons instead of the phone
   * branch's full-width, evenly-split `flex: 1` buttons — same tab bar,
   * different sizing, so this stays a prop instead of a second component. */
  fitWidth?: boolean;
}) {
  const { isAuthenticated } = useSession();
  const [tab, setTab] = useState<"loyal" | "menu">("loyal");

  const tabs = [
    {
      key: "loyal" as const,
      label: isAuthenticated ? "Mis visitas" : "Recompensas",
      icon: "workspace_premium",
    },
    { key: "menu" as const, label: "Menú", icon: "restaurant_menu" },
  ];

  return (
    <div className="flex flex-col gap-4">
      <div
        className={cn(
          "flex gap-1 rounded-full border border-border bg-surface p-1",
          fitWidth && "w-fit",
        )}
      >
        {tabs.map((t) => {
          const active = tab === t.key;
          return (
            <button
              key={t.key}
              type="button"
              onClick={() => setTab(t.key)}
              aria-pressed={active}
              className={cn(
                "flex items-center justify-center gap-1.5 rounded-full text-[13.5px] font-semibold transition-colors duration-200",
                fitWidth ? "px-[22px] py-2.5" : "flex-1 py-3",
                active
                  ? "bg-surface-2 text-foreground shadow-[inset_0_1px_0_var(--highlight),0_2px_8px_rgba(0,0,0,0.18)]"
                  : "text-foreground-faint",
              )}
            >
              <span aria-hidden className="material-symbols text-[18px]">
                {t.icon}
              </span>
              {t.label}
            </button>
          );
        })}
      </div>

      {tab === "loyal" ? loyaltySection : menuSection}
    </div>
  );
}
