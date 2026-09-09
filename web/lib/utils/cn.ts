/**
 * Minimal `className` combinator: joins truthy values with a space. Not a
 * `tailwind-merge` replacement (it does not dedupe/override conflicting
 * Tailwind classes) — components in this codebase compose variants
 * explicitly enough that plain concatenation is sufficient. Reach for a real
 * merge utility only if that stops being true.
 */
export function cn(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}
