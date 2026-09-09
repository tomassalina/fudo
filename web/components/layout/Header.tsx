"use client";

// Global phone header — logo wordmark + "Activar ubicación" pill, straight
// off the top of every mobile view in the design reference
// (docs/design-reference/Fudo App.dc.html, ~line 175: `isHome`'s header row;
// the same row is the correct chrome for Buscar/Detalle too — this was a
// real gap confirmed by visual QA, not something the reference happened to
// only draw once — see docs/visual-qa-report.md, "Resumen de hallazgos
// transversales": "Falta el header global ... en todas las páginas mobile
// revisadas"). Missing entirely from the real app before this change, which
// is also why every card showed a hardcoded "0 km" — there was no button to
// ever grant location.
//
// Phone-only by design: at >=900px WideNav already renders this same logo +
// location pill inline in its own sticky top bar (see WideNav.tsx and
// docs/design-reference/Fudo Customers.dc.html, ~line 173), so this
// component renders nothing there instead of stacking a second header on
// top of it.

import Image from "next/image";
import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { LocationButton } from "./LocationButton";

export function Header() {
  const isPhone = useIsPhoneViewport();

  if (!isPhone) {
    return null;
  }

  return (
    <div className="flex items-center justify-between px-[clamp(16px,3vw,32px)] pt-3">
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
      <LocationButton />
    </div>
  );
}
