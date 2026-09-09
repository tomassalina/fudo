"use client";

import Link from "next/link";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { buttonVariants } from "@/components/ui/Button";
import { cn } from "@/lib/utils/cn";

/**
 * The gift page's login gate — new in the latest design pass (see
 * `loggedOut` in `docs/design-reference/Fudo App.dc.html`, right after the
 * tier tiles). Anyone can browse the tiers and their perks; buying requires
 * a session, so this replaces the checkout form until `useSession()` reports
 * `isAuthenticated`. Copy and layout both differ slightly by breakpoint —
 * phone stacks everything and the wide layout runs it as a single banner
 * row — matching the two references exactly.
 */
export function LoginRequiredCard() {
  const isPhone = useIsPhoneViewport();

  return (
    <div
      className={cn(
        "mt-[22px] flex gap-3 rounded-[20px] border border-accent/32 bg-surface shadow-[inset_0_1px_0_var(--highlight)]",
        isPhone ? "flex-col p-[18px]" : "flex-row flex-wrap items-center gap-5 px-[26px] py-[22px]",
      )}
    >
      <span className="flex h-10 w-10 flex-none items-center justify-center rounded-[13px] bg-accent-soft">
        <span className="material-symbols text-[21px] text-accent">lock</span>
      </span>

      <div className={isPhone ? undefined : "min-w-[260px] flex-1"}>
        <div className="font-heading text-lg font-extrabold text-foreground">
          {isPhone ? "Iniciá sesión para comprar" : "Iniciá sesión para comprar una gift card"}
        </div>
        <div className="pt-1 text-[13px] leading-relaxed text-foreground-muted">
          {isPhone
            ? "Podés ver todas las tarjetas y sus beneficios. Para enviar una gift card necesitás una cuenta."
            : "Podés ver todas las tarjetas y sus beneficios. Para enviarla necesitás una cuenta: la gift card queda asociada a vos y podés seguir si la usaron."}
        </div>
      </div>

      <Link
        href="/perfil"
        className={cn(buttonVariants({ variant: "primary" }), isPhone ? "w-full" : "flex-none")}
      >
        Iniciar sesión
      </Link>
    </div>
  );
}
