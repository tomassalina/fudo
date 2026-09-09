import type { ElementType, ComponentPropsWithoutRef, ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

type FluidContainerProps<T extends ElementType> = {
  /** Rendered element/component — defaults to `div`. */
  as?: T;
  children: ReactNode;
  className?: string;
} & Omit<ComponentPropsWithoutRef<T>, "as" | "children" | "className">;

/**
 * The design's one repeated layout primitive for wide screens: a
 * `width: min(92vw, 1760px)` band, centered, with fluid horizontal padding
 * (`clamp(16px, 3vw, 32px)`) — see the `.container-fluid` utility in
 * `app/globals.css`. Used by the sticky nav, page sections, and anything
 * else that needs to line up with them instead of picking its own max-width.
 */
export function FluidContainer<T extends ElementType = "div">({
  as,
  children,
  className,
  ...props
}: FluidContainerProps<T>) {
  const Component = as ?? "div";

  return (
    <Component className={cn("container-fluid", className)} {...props}>
      {children}
    </Component>
  );
}
