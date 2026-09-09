import { forwardRef } from "react";
import type { ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

export type ButtonVariant = "primary" | "secondary" | "ghost";
export type ButtonSize = "sm" | "md" | "lg";

const base =
  "inline-flex items-center justify-center gap-2 rounded-full font-semibold " +
  "font-sans transition-[transform,background-color,border-color,box-shadow] " +
  "duration-200 ease-out active:scale-[0.97] disabled:pointer-events-none disabled:opacity-40";

// Every primary/CTA button in the design shares this exact gradient +
// shadow + hover lift (see e.g. "Iniciar sesión" and the search submit
// button in Fudo Customers.dc.html).
const variants: Record<ButtonVariant, string> = {
  primary:
    "border-0 bg-gradient-to-b from-cta-from to-cta-to text-white shadow-cta hover:-translate-y-px",
  secondary:
    "border border-border bg-surface text-foreground shadow-[inset_0_1px_0_var(--highlight)] hover:border-accent/50",
  ghost: "border-0 bg-transparent text-foreground-faint hover:text-foreground",
};

const sizes: Record<ButtonSize, string> = {
  sm: "px-3.5 py-1.5 text-[13px]",
  md: "px-4.5 py-2.5 text-[14px]",
  lg: "px-7 py-[15px] text-[15px]",
};

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
};

/**
 * Reusable className builder so link-styled CTAs (`next/link` wrapping the
 * same look) don't have to duplicate the variant/size logic — call this and
 * apply the result directly instead of reaching for `<Button as={Link}>`.
 */
export function buttonVariants({
  variant = "primary",
  size = "md",
  className,
}: {
  variant?: ButtonVariant;
  size?: ButtonSize;
  className?: string;
} = {}) {
  return cn(base, variants[variant], sizes[size], className);
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  function Button(
    { variant = "primary", size = "md", className, ...props },
    ref,
  ) {
    return (
      <button
        ref={ref}
        className={buttonVariants({ variant, size, className })}
        {...props}
      />
    );
  },
);
