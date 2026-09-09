import Link from "next/link";
import type { MerchantType } from "@/lib/types";
import { buscarHref, countActiveFilters, type BuscarParams } from "@/lib/utils/buscar-href";
import { FilterFields } from "./FilterFields";

// The wide-layout sticky filter column — `position: sticky; top: 96px` in
// `docs/design-reference/Fudo Customers.dc.html`'s isList branch. Distinct
// from PhoneFilterSheet (same FilterFields body, different chrome: an
// always-visible sticky card here vs. a bottom sheet there), per the task's
// explicit instruction to keep the two surfaces as separate components.

interface FilterSidebarProps {
  current: BuscarParams;
  activeType: MerchantType | null;
  availableTypes: MerchantType[];
  availableHoods: string[];
  isAuthenticated: boolean;
}

export function FilterSidebar({
  current,
  activeType,
  availableTypes,
  availableHoods,
  isAuthenticated,
}: FilterSidebarProps) {
  const activeCount = countActiveFilters(current);

  return (
    <aside className="sticky top-24 flex max-h-[calc(100vh-7rem)] w-full min-w-0 flex-col gap-4 self-start overflow-y-auto rounded-card border border-border bg-surface p-[18px] shadow-[inset_0_1px_0_var(--highlight)]">
      <div className="flex items-center justify-between">
        <h2 className="font-heading text-xl font-black text-foreground">
          Filtros
        </h2>
        {activeCount > 0 ? (
          <span className="text-[12px] font-semibold text-accent-light">
            {activeCount} activo{activeCount === 1 ? "" : "s"}
          </span>
        ) : null}
      </div>

      <FilterFields
        current={current}
        activeType={activeType}
        availableTypes={availableTypes}
        availableHoods={availableHoods}
        isAuthenticated={isAuthenticated}
      />

      <Link
        href={buscarHref(current, {
          type: null,
          tags: null,
          price: null,
          hood: null,
          dist: null,
          hideVisited: null,
        })}
        scroll={false}
        className="rounded-full border border-border bg-transparent px-4 py-2.5 text-center text-[13.5px] font-semibold text-foreground transition-colors hover:border-accent/50"
      >
        Limpiar filtros
      </Link>
    </aside>
  );
}
