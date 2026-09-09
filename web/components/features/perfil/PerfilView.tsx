"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "@/lib/session/use-session";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { ProfileHeader } from "./ProfileHeader";
import { EditProfileForm } from "./EditProfileForm";
import { VisitHistoryList } from "./VisitHistoryList";
import { RewardsSection } from "./RewardsSection";
import { getAvailableRewards, getVisitHistory, tierForVisits } from "@/lib/mock/visit-history";

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
 * Client-side `router.replace` (not `.push`, so a logged-out visit to
 * /perfil doesn't leave a dead entry in browser history) — there's no
 * middleware/session cookie to redirect on the server with yet, since the
 * whole session is a client-only mock (localStorage), so a server redirect
 * isn't possible here regardless.
 */
export function PerfilView() {
  const router = useRouter();
  const { isAuthenticated, logout } = useSession();
  const isPhone = useIsPhoneViewport();
  const [editOpen, setEditOpen] = useState(false);
  // `logout()` flips `isAuthenticated` to false synchronously, while this
  // page is still mounted (client-side navigation away hasn't resolved
  // yet) — without this guard, the effect below would race handleLogout's
  // own `router.push("/")` with its own `router.replace("/login")` and the
  // logout button would land the consumer on /login instead of home.
  const loggingOutRef = useRef(false);

  useEffect(() => {
    if (!isAuthenticated && !loggingOutRef.current) {
      router.replace("/login");
    }
  }, [isAuthenticated, router]);

  if (!isAuthenticated) {
    // Brief flash before the effect above redirects — render nothing rather
    // than a half-populated profile for a consumer that doesn't exist.
    return null;
  }

  const visitHistory = getVisitHistory();
  const rewards = getAvailableRewards();
  const topTier = visitHistory.length
    ? tierForVisits(Math.max(...visitHistory.map((entry) => entry.progress.visits)))
    : "Bronce";

  function handleLogout() {
    loggingOutRef.current = true;
    logout();
    router.push("/");
  }

  return (
    <FluidContainer as="main" className="flex flex-col gap-8 py-8 pb-24">
      <div
        className={
          isPhone
            ? "flex flex-col gap-8"
            : "grid grid-cols-[minmax(240px,280px)_minmax(0,1fr)] items-start gap-8"
        }
      >
        <ProfileHeader topTier={topTier} onEdit={() => setEditOpen(true)} />

        <div className="flex flex-col gap-8">
          <VisitHistoryList entries={visitHistory} />
          <RewardsSection entries={rewards} />

          <button
            type="button"
            onClick={handleLogout}
            className="flex items-center justify-center gap-2.5 rounded-full border border-border bg-surface px-4 py-3.5 text-[14px] font-semibold text-accent-light transition-colors hover:border-accent/50"
          >
            <span aria-hidden className="material-symbols text-[19px]">
              logout
            </span>
            Cerrar sesión
          </button>
        </div>
      </div>

      <EditProfileForm open={editOpen} onClose={() => setEditOpen(false)} />
    </FluidContainer>
  );
}
