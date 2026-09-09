import { describe, expect, it } from "vitest";
import { act, renderHook } from "@testing-library/react";
import { useGiftPurchase } from "@/lib/gift/use-gift-purchase";

describe("useGiftPurchase", () => {
  it("starts on the Clásica tier with its fixed amount payable", () => {
    const { result } = renderHook(() => useGiftPurchase());

    expect(result.current.tierKey).toBe("clasica");
    expect(result.current.isCustomTier).toBe(false);
    expect(result.current.payAmount).toBe(12_000);
    expect(result.current.canPay).toBe(true);
    expect(result.current.buyLabel).toBe("Comprar y enviar $12.000");
  });

  it("switches to a fixed-amount tier and updates the pay amount", () => {
    const { result } = renderHook(() => useGiftPurchase());

    act(() => result.current.selectTier("gold"));
    expect(result.current.payAmount).toBe(40_000);

    act(() => result.current.selectTier("black"));
    expect(result.current.payAmount).toBe(120_000);
  });

  it("blocks payment on the custom tier until a valid amount is entered", () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));

    expect(result.current.canPay).toBe(false);
    expect(result.current.customHint).toEqual({
      tone: "neutral",
      message: "Entre $121.000 y $1.000.000",
    });
    expect(result.current.buyLabel).toBe("Ingresá un monto");
  });

  it("rejects a custom amount below the $121.000 minimum", () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));
    act(() => result.current.onCustomAmountChange("50000"));

    expect(result.current.customAmount).toBe("50.000");
    expect(result.current.canPay).toBe(false);
    expect(result.current.customHint).toEqual({
      tone: "error",
      message: "El mínimo es $121.000",
    });
    expect(result.current.buyLabel).toBe("Corregí el monto");
  });

  it("rejects a custom amount above the $1.000.000 maximum", () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));
    // onCustomAmountChange caps raw input at 7 digits, matching the design's
    // `.slice(0, 7)` — 9999999 stays 7 digits and is still over the max.
    act(() => result.current.onCustomAmountChange("9999999"));

    expect(result.current.canPay).toBe(false);
    expect(result.current.customHint.tone).toBe("error");
    expect(result.current.customHint.message).toBe("El máximo es $1.000.000");
  });

  it("accepts a custom amount within [$121.000, $1.000.000] and formats it as the buy amount", () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));
    act(() => result.current.onCustomAmountChange("250000"));

    expect(result.current.customAmount).toBe("250.000");
    expect(result.current.canPay).toBe(true);
    expect(result.current.payAmount).toBe(250_000);
    expect(result.current.customHint).toEqual({
      tone: "success",
      message: "Gift card de $250.000",
    });
    expect(result.current.buyLabel).toBe("Comprar y enviar $250.000");
  });

  it("accepts the exact boundary amounts", () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));

    act(() => result.current.onCustomAmountChange("121000"));
    expect(result.current.canPay).toBe(true);

    act(() => result.current.onCustomAmountChange("1000000"));
    expect(result.current.canPay).toBe(true);
  });

  it("does not mark itself purchased when buy() is called while unpayable", () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));

    act(() => result.current.buy());
    expect(result.current.purchased).toBe(false);
  });

  it("marks itself purchased when buy() is called with a payable amount, and resets on resetPurchase()", () => {
    const { result } = renderHook(() => useGiftPurchase());

    act(() => result.current.setRecipientPhone("+54 9 11 5555 5555"));
    act(() => result.current.buy());
    expect(result.current.purchased).toBe(true);

    act(() => result.current.resetPurchase());
    expect(result.current.purchased).toBe(false);
    expect(result.current.recipientPhone).toBe("");
  });
});
