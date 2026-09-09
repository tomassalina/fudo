import type { CustomAmountHint } from "@/lib/gift/use-gift-purchase";
import { cn } from "@/lib/utils/cn";

export type CustomAmountInputProps = {
  value: string;
  onChange: (rawInput: string) => void;
  hint: CustomAmountHint;
};

const hintTextTone: Record<CustomAmountHint["tone"], string> = {
  neutral: "text-foreground-faint",
  error: "text-accent-light",
  success: "text-success",
};

const hintIcon: Record<CustomAmountHint["tone"], string> = {
  neutral: "info",
  error: "error",
  success: "check_circle",
};

const borderTone: Record<CustomAmountHint["tone"], string> = {
  neutral: "border-border",
  error: "border-accent",
  success: "border-success/55",
};

/**
 * The "Platinum" tier's free-amount field — only rendered while that tier is
 * selected. Validation copy/thresholds match the reference exactly (see
 * `lib/gift/use-gift-purchase.ts`'s `customError` derivation).
 */
export function CustomAmountInput({ value, onChange, hint }: CustomAmountInputProps) {
  return (
    <div className="animate-fudo-in pt-[22px]">
      <div className="pb-3 text-[11px] font-bold tracking-[0.1em] text-foreground-faint">
        MONTO PLATINUM
      </div>
      <div className="flex flex-wrap items-center gap-3.5">
        <div
          className={cn(
            "flex w-full items-center gap-2.5 rounded-[18px] border-[1.5px] bg-surface px-[18px] py-4 shadow-[inset_0_1px_0_var(--highlight)] transition-colors duration-200 sm:w-80",
            borderTone[hint.tone],
          )}
        >
          <span className="font-heading text-2xl font-black text-foreground-faint">$</span>
          <input
            value={value}
            onChange={(event) => onChange(event.target.value)}
            placeholder="121.000"
            inputMode="numeric"
            aria-label="Monto de la gift card"
            className="min-w-0 flex-1 border-0 bg-transparent font-heading text-2xl font-black text-foreground outline-none"
          />
        </div>
        <div className={cn("flex min-h-5 items-center gap-1.5 text-[12.5px]", hintTextTone[hint.tone])}>
          <span className="material-symbols text-base">{hintIcon[hint.tone]}</span>
          {hint.message}
        </div>
      </div>
    </div>
  );
}
