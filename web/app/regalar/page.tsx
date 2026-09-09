"use client";

// Client Component: the whole page is one interactive purchase flow (tier
// selection, custom-amount validation, login gating), so there's no
// server-rendered slice worth splitting off — unlike /buscar, which is
// mostly static per request.

import { useSession } from "@/lib/session/use-session";
import { useGiftPurchase } from "@/lib/gift/use-gift-purchase";
import { FluidContainer } from "@/components/ui/FluidContainer";
import { GiftTierPicker } from "@/components/features/regalar/GiftTierPicker";
import { CustomAmountInput } from "@/components/features/regalar/CustomAmountInput";
import { LoginRequiredCard } from "@/components/features/regalar/LoginRequiredCard";
import { GiftCheckoutForm } from "@/components/features/regalar/GiftCheckoutForm";
import { GiftPurchaseSuccess } from "@/components/features/regalar/GiftPurchaseSuccess";

export default function RegalarPage() {
  const { isAuthenticated } = useSession();
  const gift = useGiftPurchase();

  return (
    <main className="flex-1 pt-[clamp(24px,4vw,40px)] pb-[clamp(48px,10vw,90px)]">
      <FluidContainer className="flex flex-col">
        <div className="max-w-[620px]">
          <h1 className="text-title-fluid font-heading font-black text-foreground">
            Regalar
          </h1>
          <p className="pt-2.5 text-base leading-relaxed text-foreground-muted">
            Elegí una gift card de Fudo para usar en cualquier local de la red.
          </p>
        </div>

        <div className="pt-7">
          <GiftTierPicker
            tiers={gift.tiers}
            selectedKey={gift.tierKey}
            customAmountLabel={
              gift.isCustomTier && gift.payAmount ? gift.payAmountLabel : "Tu monto"
            }
            onSelect={gift.selectTier}
          />
        </div>

        {gift.isCustomTier ? (
          <CustomAmountInput
            value={gift.customAmount}
            onChange={gift.onCustomAmountChange}
            hint={gift.customHint}
          />
        ) : null}

        {!isAuthenticated ? (
          <LoginRequiredCard />
        ) : gift.purchased ? (
          <GiftPurchaseSuccess
            tier={gift.selectedTier}
            amountLabel={gift.payAmountLabel}
            recipientPhone={gift.recipientPhone}
            giftId={gift.purchasedGiftId}
            onDone={gift.resetPurchase}
          />
        ) : (
          <GiftCheckoutForm
            recipientPhone={gift.recipientPhone}
            onRecipientPhoneChange={gift.setRecipientPhone}
            message={gift.message}
            onMessageChange={gift.setMessage}
            payAmountLabel={gift.payAmountLabel}
            buyLabel={gift.buyLabel}
            canPay={gift.canPay}
            onBuy={gift.buy}
            error={gift.purchaseError}
          />
        )}
      </FluidContainer>
    </main>
  );
}
