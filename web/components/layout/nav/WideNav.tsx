"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSession } from "@/lib/session/use-session";
import { Sheet } from "@/components/ui/Sheet";
import { QrSheetContent } from "@/components/features/perfil/QrSheetContent";
import { Button, buttonVariants } from "@/components/ui/Button";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { LocationButton } from "@/components/layout/LocationButton";
import { cn } from "@/lib/utils/cn";
import { NAV_LEFT, visibleNavRight, type NavItemDef } from "./nav-items";
import { isActiveHref } from "./is-active-href";

function NavLink({ item, active }: { item: NavItemDef; active: boolean }) {
  return (
    <Link
      href={item.href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex items-center gap-1.5 rounded-full px-3.5 py-2 text-sm font-semibold transition-colors duration-200",
        active
          ? "bg-accent-soft text-accent"
          : "text-foreground-muted hover:text-foreground",
      )}
    >
      <span className="material-symbols text-[19px]">{item.icon}</span>
      {item.label}
    </Link>
  );
}

/**
 * Sticky top nav for wide widths (>= 900px) — see the `position: sticky;
 * top: 0` header in `docs/design-reference/Fudo Customers.dc.html`. Unlike
 * the phone layout there are no bottom tabs; the same four destinations run
 * inline next to the logo, with the same Perfil login-gate.
 */
export function WideNav() {
  const pathname = usePathname();
  const { isAuthenticated } = useSession();
  const [qrOpen, setQrOpen] = useState(false);
  const navRight = visibleNavRight(isAuthenticated);

  return (
    <>
      <header className="sticky top-0 z-30 border-b border-border bg-nav backdrop-blur-md">
        <FluidContainer className="flex h-17 items-center gap-7">
          <Link href="/" aria-label="Fudo" className="flex flex-none items-center">
            <Image
              src="/fudo-logo.png"
              alt="Fudo"
              width={200}
              height={50}
              priority
              className="h-[22px] w-auto"
            />
          </Link>

          <div className="flex items-center gap-1.5">
            {NAV_LEFT.map((item) => (
              <NavLink
                key={item.key}
                item={item}
                active={isActiveHref(pathname, item.href)}
              />
            ))}
            {navRight.map((item) => (
              <NavLink
                key={item.key}
                item={item}
                active={isActiveHref(pathname, item.href)}
              />
            ))}
          </div>

          <div className="flex-1" />

          <LocationButton />

          {isAuthenticated ? (
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => setQrOpen(true)}
            >
              <span className="material-symbols text-[18px]">
                qr_code_scanner
              </span>
              Mi código
            </Button>
          ) : (
            <Link
              href="/perfil"
              className={buttonVariants({ variant: "primary", size: "sm" })}
            >
              <span className="material-symbols text-[18px]">login</span>
              Iniciar sesión
            </Link>
          )}
        </FluidContainer>
      </header>

      <Sheet open={qrOpen} onClose={() => setQrOpen(false)} title="Tu código Fudo">
        <QrSheetContent />
      </Sheet>
    </>
  );
}
