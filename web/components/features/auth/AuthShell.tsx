"use client";

import type { ReactNode } from "react";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { cn } from "@/lib/utils/cn";

export type AuthShellProps = {
  heading: string;
  subtitle: string;
  /** The `<form>` element itself. */
  children: ReactNode;
  /** The "¿No tenés cuenta? / ¿Ya tenés cuenta?" line under the form. */
  footer: ReactNode;
};

/**
 * Shared chrome for LoginForm/RegisterForm — the brand badge, heading and
 * subtitle, translated from the "isProfile / loggedOut" view in both design
 * references:
 *   docs/design-reference/Fudo App.dc.html        (phone, vw < 900)
 *   docs/design-reference/Fudo Customers.dc.html  (wide, vw >= 900)
 *
 * The two references only really differ in whether the content sits in a
 * bordered/shadowed panel (wide) or flows directly on the page background
 * (phone) plus a handful of type-scale tweaks — reused here via the same
 * `useIsPhoneViewport` structural switch every other layout piece in this
 * app already branches on (see AppNav), rather than a Tailwind `sm:`/`md:`
 * breakpoint of our own.
 */
export function AuthShell({ heading, subtitle, children, footer }: AuthShellProps) {
  const isPhone = useIsPhoneViewport();

  return (
    <main
      className={cn(
        "flex flex-1 flex-col items-center",
        isPhone ? "px-5 pb-16 pt-8" : "px-6 pb-20 pt-10",
      )}
    >
      <div
        className={cn(
          "flex w-full flex-col items-center",
          isPhone
            ? "max-w-[380px]"
            : "max-w-[440px] rounded-[24px] border border-border bg-surface px-9 py-10 shadow-[0_24px_60px_var(--shadow),inset_0_1px_0_var(--highlight)]",
        )}
      >
        <div className="flex h-17 w-17 flex-none items-center justify-center rounded-card bg-accent">
          <span className="font-heading text-[26px] font-black text-white">F</span>
        </div>

        <h1
          className={cn(
            "font-heading font-black leading-none text-foreground",
            isPhone ? "pt-4.5 text-[30px]" : "pt-5 text-[32px]",
          )}
        >
          {heading}
        </h1>
        <p
          className={cn(
            "text-foreground-muted",
            isPhone ? "pt-1.5 text-[14px]" : "pt-2 text-[14.5px]",
          )}
        >
          {subtitle}
        </p>

        <div className={cn("w-full", isPhone ? "pt-6.5" : "pt-7")}>{children}</div>

        <p
          className={cn(
            "text-foreground-muted",
            isPhone ? "pt-4 text-[13px]" : "pt-4.5 text-[13.5px]",
          )}
        >
          {footer}
        </p>
      </div>
    </main>
  );
}
