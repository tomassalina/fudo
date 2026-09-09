import Link from "next/link";
import type { MerchantType } from "@/lib/types";
import { MERCHANT_TYPE_LABELS, TAG_LABELS } from "@/lib/mock/merchants";

// Filter chips for /buscar, styled after the design reference's pill-shaped
// filter chip row (docs/design-reference/Fudo App.dc.html, `aiChips` in the
// `isList` state — active: accent-tinted fill + border, inactive: neutral
// surface + faint text).
//
// Deliberately a Server Component, not a client island: toggling a chip only
// needs to compute a new URL and navigate to it, which next/link already
// does client-side (soft navigation, no full reload) without any component
// state — and, unlike a client onClick + router.push, a plain <Link> still
// works with JS disabled, matching the page's no-JS-required search form.
// SearchBar.tsx is "use client" for a real reason (rotating the placeholder
// needs client state); this component has no equivalent need.
//
// `type` is single-select (a merchant only has one type); `tags` is
// multi-select and OR'd together, then AND'd with type and the text query —
// per the reference's own filter semantics (F0.type is a single value,
// F0.diet/dishDiet a single value too, but the AI-derived attribute chips in
// `isList` toggle independently).

interface FilterChipsProps {
  query: string;
  activeType: MerchantType | null;
  activeTags: string[];
  availableTypes: MerchantType[];
  availableTags: string[];
}

function buildHref(
  query: string,
  type: MerchantType | null,
  tags: string[],
): string {
  const params = new URLSearchParams();
  if (query) params.set("q", query);
  if (type) params.set("type", type);
  if (tags.length > 0) params.set("tags", tags.join(","));

  const qs = params.toString();
  return qs ? `/buscar?${qs}` : "/buscar";
}

const chipBase =
  "inline-flex flex-none items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-[13px] font-semibold whitespace-nowrap transition-colors";
const chipActive = "border-accent/35 bg-accent-soft text-accent-light";
const chipInactive =
  "border-border bg-surface text-foreground-faint hover:border-accent/50 hover:text-foreground";

export function FilterChips({
  query,
  activeType,
  activeTags,
  availableTypes,
  availableTags,
}: FilterChipsProps) {
  if (availableTypes.length === 0 && availableTags.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-col gap-2">
      {availableTypes.length > 0 ? (
        <div className="flex flex-wrap gap-2">
          {availableTypes.map((type) => {
            const active = activeType === type;
            return (
              <Link
                key={type}
                href={buildHref(query, active ? null : type, activeTags)}
                scroll={false}
                aria-pressed={active}
                className={`${chipBase} ${active ? chipActive : chipInactive}`}
              >
                <span aria-hidden className="material-symbols text-[14px]">
                  storefront
                </span>
                {MERCHANT_TYPE_LABELS[type]}
              </Link>
            );
          })}
        </div>
      ) : null}

      {availableTags.length > 0 ? (
        <div className="flex flex-wrap gap-2">
          {availableTags.map((tag) => {
            const active = activeTags.includes(tag);
            const nextTags = active
              ? activeTags.filter((t) => t !== tag)
              : [...activeTags, tag];
            return (
              <Link
                key={tag}
                href={buildHref(query, activeType, nextTags)}
                scroll={false}
                aria-pressed={active}
                className={`${chipBase} ${active ? chipActive : chipInactive}`}
              >
                <span aria-hidden className="material-symbols text-[14px]">
                  auto_awesome
                </span>
                {TAG_LABELS[tag] ?? tag}
              </Link>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
