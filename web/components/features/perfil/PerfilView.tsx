"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "@/lib/session/use-session";
import { useRequireAuth } from "@/lib/session/use-require-auth";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { cn } from "@/lib/utils/cn";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { SegmentedControl, type SegmentedOption } from "@/components/ui/SegmentedControl";
import { ProfileHeader } from "./ProfileHeader";
import { ProfileSidebar } from "./ProfileSidebar";
import { EditProfileForm } from "./EditProfileForm";
import { VisitHistoryList } from "./VisitHistoryList";
import { RewardsSection } from "./RewardsSection";
import { FavoritesTab } from "./FavoritesTab";
import { SettingsTab } from "./SettingsTab";
import { useVisitHistory } from "@/lib/visits/use-visit-history";
import { buildVisitEntries, topTierFor } from "@/lib/visits/build-visit-entries";
import type { RewardEntry, VisitHistoryEntry } from "@/lib/types";

type ProfileTab = "visitas" | "favoritos" | "ajustes";

// `pTabs` in both design references — same 3 tabs/icons/order
// (`docs/design-reference/Fudo App.dc.html`, ~line 1876). Shared by both
// viewport nav renderings below: the horizontal pill `SegmentedControl` on
// phone, and `ProfileSidebar`'s vertical rows on wide (`Fudo
// Customers.dc.html`'s own `pTabs`, ~line 805) — same keys/icons/labels,
// just two different chrome components around them.
const PROFILE_TABS: SegmentedOption<ProfileTab>[] = [
  { key: "visitas", label: "Visitas", icon: "history" },
  { key: "favoritos", label: "Favoritos", icon: "favorite_border" },
  { key: "ajustes", label: "Ajustes", icon: "settings" },
];

/**
 * /perfil requires a session — there's no anonymous "browse your own
 * profile" state, unlike /regalar (which shows a login-required *card*
 * inline while still rendering the tier picker for everyone). The
 * distinction: /regalar has real content to show while logged out (you can
 * still pick a gift amount before paying), /perfil has none — every piece of
 * it (name, DNI, visit history, rewards, QR) only exists for a real
 * consumer. WideNav's existing "Iniciar sesión" button already links here
 * expecting exactly this redirect (see WideNav.tsx), the strongest signal
 * slice 1 anticipated this exact behavior.
 *
 * The redirect-when-logged-out and "brief flash of nothing" logic live in
 * `useRequireAuth()` (lib/session/use-require-auth.ts), not inline here
 * anymore — see that file's header comment for why a plain
 * `useEffect(() => { if (!isAuthenticated) router.replace("/login") })`
 * incorrectly bounced a real, logged-in consumer to `/login` on every hard
 * reload of this exact page, and how the hook fixes it. `router.replace`
 * (not `.push`) so a logged-out visit doesn't leave a dead entry in browser
 * history — there's no middleware/session cookie to redirect on the server
 * with yet, since the whole session is client-only (localStorage), so a
 * server redirect isn't possible here regardless.
 */
export function PerfilView() {
  const router = useRouter();
  const { logout } = useSession();
  const { ready, suppressNextRedirect } = useRequireAuth();
  const isPhone = useIsPhoneViewport();
  const [editOpen, setEditOpen] = useState(false);
  const [activeTab, setActiveTab] = useState<ProfileTab>("visitas");
  const { visitSummaries } = useVisitHistory();
  const [visitHistory, setVisitHistory] = useState<VisitHistoryEntry[]>([]);
  const [rewards, setRewards] = useState<RewardEntry[]>([]);

  // Derives both Perfil sections from the real `visit_summaries` the hook
  // above loaded — resolving each visited merchant + its real loyalty rules
  // is async (lib/visits/build-visit-entries.ts), so this can't be a plain
  // render-time `const` the way the old mock derivation was. Routed through
  // `Promise.resolve(...).then()` even for the empty case so no `setState`
  // call here is synchronous within the effect body (same constraint as
  // lib/visits/use-visit-history.ts — see its header comment).
  useEffect(() => {
    let cancelled = false;
    const request =
      visitSummaries.length === 0
        ? Promise.resolve({ visitHistory: [], rewards: [] })
        : buildVisitEntries(visitSummaries);

    request
      .then((result) => {
        if (cancelled) return;
        setVisitHistory(result.visitHistory);
        setRewards(result.rewards);
      })
      .catch(() => {
        // `buildVisitEntries` already catches a per-merchant network/5xx
        // failure internally (see its header comment) — a rejection here
        // means something else went wrong (a bug, not a flaky merchant).
        // Explicitly reset both sections to empty rather than leaving an
        // unhandled rejection and a stale/half-populated `visitHistory`/
        // `rewards` from a previous render.
        if (cancelled) return;
        setVisitHistory([]);
        setRewards([]);
      });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- re-derive whenever the *set* of summaries changes, not on every array identity change from unrelated re-renders (same pattern as FavoritesTab.tsx).
  }, [visitSummaries.map((summary) => `${summary.merchant_id}:${summary.count}`).join(",")]);

  const topTier = topTierFor(visitHistory);

  if (!ready) {
    // Either still settling (see useRequireAuth) or genuinely logged out
    // and a redirect to /login is already in flight — render nothing
    // rather than a half-populated profile for a consumer that doesn't
    // exist yet/anymore.
    return null;
  }

  function handleLogout() {
    // Without this, useRequireAuth's own redirect effect would race this
    // function's `router.push("/")` the moment `logout()` flips
    // `isAuthenticated` to false, and could land the consumer on /login
    // instead of home.
    suppressNextRedirect();
    logout();
    router.push("/");
  }

  // Shared across both viewport layouts below — only the nav chrome around
  // these panels differs (horizontal SegmentedControl vs. ProfileSidebar's
  // vertical rows), the panels themselves are identical.
  const tabPanels = (
    <>
      {activeTab === "visitas" ? (
        <div
          role="tabpanel"
          id="segmented-tabpanel-visitas"
          aria-labelledby="segmented-tab-visitas"
          className="flex flex-col gap-8"
        >
          <VisitHistoryList entries={visitHistory} />
          <RewardsSection entries={rewards} />
        </div>
      ) : null}

      {activeTab === "favoritos" ? (
        <div
          role="tabpanel"
          id="segmented-tabpanel-favoritos"
          aria-labelledby="segmented-tab-favoritos"
        >
          <FavoritesTab />
        </div>
      ) : null}

      {activeTab === "ajustes" ? (
        <div
          role="tabpanel"
          id="segmented-tabpanel-ajustes"
          aria-labelledby="segmented-tab-ajustes"
        >
          {/* PerfilView already returned `null` above when logged out, so
              `useSession().consumer` is guaranteed non-null here — but
              TypeScript can't see that guard from inside a sibling
              component. Re-read it locally instead of threading a
              possibly-null prop through SettingsTab. */}
          <SettingsTabContent onEdit={() => setEditOpen(true)} onLogout={handleLogout} />
        </div>
      ) : null}
    </>
  );

  return (
    <FluidContainer
      as="main"
      className={cn("flex flex-col py-8 pb-24", isPhone && "items-center")}
    >
      {isPhone ? (
        <div className="flex w-full max-w-[620px] flex-col gap-6">
          <ProfileHeader topTier={topTier} />

          <SegmentedControl
            options={PROFILE_TABS}
            value={activeTab}
            onChange={setActiveTab}
            label="Secciones de tu perfil"
          />

          {tabPanels}
        </div>
      ) : (
        // Wide (`vw >= 900`): sticky left rail (identity + vertical nav,
        // `ProfileSidebar`) next to the active tab's content — the design
        // reference's `minmax(240px, 280px) minmax(0, 1fr)` grid exactly
        // (`docs/design-reference/Fudo Customers.dc.html`, ~line 792).
        <div
          className="grid w-full items-start gap-6"
          style={{ gridTemplateColumns: "minmax(240px,280px) minmax(0,1fr)" }}
        >
          <ProfileSidebar
            topTier={topTier}
            options={PROFILE_TABS}
            value={activeTab}
            onChange={setActiveTab}
          />

          <div className="flex min-w-0 flex-col gap-8">{tabPanels}</div>
        </div>
      )}

      <EditProfileForm open={editOpen} onClose={() => setEditOpen(false)} />
    </FluidContainer>
  );
}

/** Thin wrapper so `SettingsTab` (which needs a non-null `Consumer`) doesn't
 * have to re-derive/guard `useSession()` itself. */
function SettingsTabContent({
  onEdit,
  onLogout,
}: {
  onEdit: () => void;
  onLogout: () => void;
}) {
  const { consumer } = useSession();
  if (!consumer) return null;
  return <SettingsTab consumer={consumer} onEdit={onEdit} onLogout={onLogout} />;
}
