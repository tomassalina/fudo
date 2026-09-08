import type { ButtonHTMLAttributes } from "react";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement>;

/**
 * Minimal atomic Button. Starter example for components/ui — extend or
 * replace once a real design system lands.
 */
export function Button({ className = "", ...props }: ButtonProps) {
  return (
    <button
      className={`rounded-full bg-accent px-5 py-2 font-medium text-white transition-colors hover:bg-accent-dark ${className}`}
      {...props}
    />
  );
}
