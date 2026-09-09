import Link from "next/link";
import { TAG_LABELS } from "@/lib/mock/merchants";
import { buscarHref, type BuscarParams } from "@/lib/utils/buscar-href";
import { cn } from "@/lib/utils/cn";

// The "AI-powered" attribute chips (`aiChips` in both design references) —
// multi-select, OR'd together, styled with the auto_awesome sparkle icon to
// read as AI-surfaced attributes rather than a manual filter, even though
// today they're the same real `tags` filter dimension (see
// lib/mock/search.ts's header comment: this app never had a real NLP tagger,
// the sparkle styling is the honest stand-in the design itself specifies).
// Plain `<Link>`s, same no-JS-required rationale as TypeFilterGrid.

interface AiChipsProps {
  current: BuscarParams;
  activeTags: string[];
  availableTags: string[];
  className?: string;
}

export function AiChips({
  current,
  activeTags,
  availableTags,
  className,
}: AiChipsProps) {
  if (availableTags.length === 0) return null;

  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {availableTags.map((tag) => {
        const active = activeTags.includes(tag);
        const nextTags = active
          ? activeTags.filter((t) => t !== tag)
          : [...activeTags, tag];

        return (
          <Link
            key={tag}
            href={buscarHref(current, { tags: nextTags.join(",") || null })}
            scroll={false}
            aria-pressed={active}
            className={cn(
              "inline-flex flex-none items-center gap-1.5 whitespace-nowrap rounded-full border px-3.5 py-1.5 text-[13px] font-semibold transition-colors duration-200",
              active
                ? "border-accent/35 bg-accent-soft text-accent-light"
                : "border-border bg-surface text-foreground-faint hover:border-accent/50 hover:text-foreground",
            )}
          >
            <span aria-hidden className="material-symbols text-[14px]">
              auto_awesome
            </span>
            {TAG_LABELS[tag] ?? tag}
          </Link>
        );
      })}
    </div>
  );
}
