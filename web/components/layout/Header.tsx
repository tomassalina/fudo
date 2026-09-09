"use client";

// Global phone header — logo wordmark + "Activar ubicación" pill, straight
// off the top of every mobile view in the design reference
// (docs/design-reference/Fudo App.dc.html, ~line 175: `isHome`'s header row).
// Missing entirely from the real app before this change, which is also why
// every card showed a hardcoded "0 km" — there was no button to ever grant
// location.
//
// NOT rendered on /buscar (phone): confirmed against the design reference's
// own `isList`/`isMap` views, which start directly with the search bar —
// no logo/location row above it (unlike `isHome`). Used only by Inicio and
// Detalle on phone; see those pages' own `<Header />` usage.
//
// Phone-only by design: at >=900px WideNav already renders this same logo +
// location pill (plus its own "Iniciar sesión" CTA) inline in its own sticky
// top bar (see WideNav.tsx and docs/design-reference/Fudo Customers.dc.html,
// ~line 173), so this component renders nothing there instead of stacking a
// second header on top of it.
//
// The "Iniciar sesión" link goes to the same destination as WideNav's own
// logged-out CTA, gated on `useSession()` the same way — only shown while
// logged out. Icon-only here (unlike WideNav's labeled button): the logo +
// LocationButton pill already use most of a 390px row, and the full "Iniciar
// sesión" label pushed the row past the viewport — same icon-only tradeoff
// PhoneNav already makes for its QR trigger in the same tight bottom pill.

import Image from "next/image";
import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { useSession } from "@/lib/session/use-session";
import { buttonVariants } from "@/components/ui/Button";
import { LocationButton } from "./LocationButton";

export function Header() {
  const isPhone = useIsPhoneViewport();
  const { isAuthenticated } = useSession();

  if (!isPhone) {
    return null;
  }

  return (
    <div className="flex items-center justify-between gap-2 px-[clamp(16px,3vw,32px)] pt-3">
      <Link href="/" aria-label="Fudo" className="flex flex-none items-center">
        <Image
          src="/fudo-logo.png"
          alt="Fudo"
          width={200}
          height={50}
          priority
          className="h-5 w-auto"
        />
      </Link>
      <div className="flex flex-none items-center gap-2">
        <LocationButton />
        {isAuthenticated ? null : (
          <Link
            href="/login"
            aria-label="Iniciar sesión"
            className={buttonVariants({ variant: "primary", size: "icon" })}
          >
            <span className="material-symbols text-[19px]">login</span>
          </Link>
        )}
      </div>
    </div>
  );
}
