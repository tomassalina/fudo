import { beforeEach, describe, expect, it, vi } from "vitest";
import { act, renderHook, waitFor } from "@testing-library/react";
import { ApiError } from "@/lib/api/client";

// use-gift-purchase.ts is now backed by the real `POST /api/v1/gifts`
// (lib/api/gifts.ts) — these tests mock the API client and the session's
// `forceLogout`, same pattern as
// __tests__/lib/favorites/favorites-store.test.ts.
const { createGiftMock, forceLogoutMock } = vi.hoisted(() => ({
  createGiftMock: vi.fn(),
  forceLogoutMock: vi.fn(),
}));

vi.mock("@/lib/api/gifts", async () => {
  const actual = await vi.importActual<typeof import("@/lib/api/gifts")>(
    "@/lib/api/gifts",
  );
  return { ...actual, createGift: createGiftMock };
});

vi.mock("@/lib/session/session-provider", () => ({
  forceLogout: forceLogoutMock,
}));

const { useGiftPurchase } = await import("@/lib/gift/use-gift-purchase");

describe("useGiftPurchase", () => {
  beforeEach(() => {
    createGiftMock.mockReset();
    forceLogoutMock.mockReset();
  });

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

  it("does not call the API or mark itself purchased when buy() is called while unpayable", async () => {
    const { result } = renderHook(() => useGiftPurchase());
    act(() => result.current.selectTier("custom"));

    await act(() => result.current.buy());
    expect(createGiftMock).not.toHaveBeenCalled();
    expect(result.current.purchased).toBe(false);
  });

  it("calls POST /api/v1/gifts with the tier's type/amount and marks itself purchased with the real gift id, resetting on resetPurchase()", async () => {
    createGiftMock.mockResolvedValue({ id: 129, status: "pending" });
    const { result } = renderHook(() => useGiftPurchase());

    act(() => result.current.setRecipientPhone("+54 9 11 5555 5555"));
    act(() => result.current.setMessage("Feliz cumple"));
    await act(() => result.current.buy());

    expect(createGiftMock).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "classic",
        amount: 12_000,
        recipient_phone: "+54 9 11 5555 5555",
        message: "Feliz cumple",
      }),
    );
    expect(result.current.purchased).toBe(true);
    expect(result.current.purchasedGiftId).toBe(129);

    act(() => result.current.resetPurchase());
    expect(result.current.purchased).toBe(false);
    expect(result.current.purchasedGiftId).toBe(null);
    expect(result.current.recipientPhone).toBe("");
  });

  it("omits `message` entirely when left blank", async () => {
    createGiftMock.mockResolvedValue({ id: 1, status: "pending" });
    const { result } = renderHook(() => useGiftPurchase());

    await act(() => result.current.buy());

    expect(createGiftMock).toHaveBeenCalledWith(
      expect.not.objectContaining({ message: expect.anything() }),
    );
  });

  it("surfaces a 422 recipient_phone validation error from the backend", async () => {
    createGiftMock.mockRejectedValue(
      new ApiError("API request failed", {
        status: 422,
        body: { errors: { recipient_phone: ["can't be blank"] } },
      }),
    );
    const { result } = renderHook(() => useGiftPurchase());

    await act(() => result.current.buy());

    expect(result.current.purchased).toBe(false);
    expect(result.current.purchaseError).toBe(
      "Ingresá un teléfono de destinatario válido.",
    );
  });

  it("clears the session (forceLogout) instead of showing an inline error on a 401", async () => {
    createGiftMock.mockRejectedValue(
      new ApiError("API request failed", { status: 401 }),
    );
    const { result } = renderHook(() => useGiftPurchase());

    await act(() => result.current.buy());

    await waitFor(() => expect(forceLogoutMock).toHaveBeenCalledTimes(1));
    expect(result.current.purchased).toBe(false);
    expect(result.current.purchaseError).toBe(null);
  });
});
