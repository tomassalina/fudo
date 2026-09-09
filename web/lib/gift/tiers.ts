// Gift card tier catalogue — mirrors the `TIERS` constant in both design
// references (`docs/design-reference/Fudo App.dc.html` and
// `Fudo Customers.dc.html`, search `TIERS = [`). Three fixed-amount tiers
// plus a "Platinum" tier where the buyer picks their own amount (see
// `CUSTOM_AMOUNT_MIN`/`MAX`, taken from the reference's inline validation:
// `n < 121000` / `n > 1000000`).

export type GiftTierKey = "clasica" | "gold" | "black" | "custom";

export interface GiftTier {
  key: GiftTierKey;
  /** Small badge label on the card face (design: "CLASSIC" / "GOLD" / "BLACK" / "PLATINUM"). */
  badge: string;
  /** Fixed amount in ARS, or `null` for the custom-amount ("Platinum") tier. */
  amount: number | null;
  perk: string;
  gradient: string;
  badgeColor: string;
  ringColor: string;
}

export const GIFT_TIERS: readonly GiftTier[] = [
  {
    key: "clasica",
    badge: "CLASSIC",
    amount: 12_000,
    perk: "Válida en toda la red Fudo",
    gradient: "linear-gradient(150deg, #FF6337 0%, #E8431A 60%, #B93412 100%)",
    badgeColor: "rgba(255,255,255,0.8)",
    ringColor: "rgba(255,99,55,0.6)",
  },
  {
    key: "gold",
    badge: "GOLD",
    amount: 40_000,
    perk: "Sumás 2x visitas · postre de bienvenida",
    gradient: "linear-gradient(150deg, #3B2A14 0%, #7A5A1F 45%, #E0B95C 100%)",
    badgeColor: "#FFE9AE",
    ringColor: "rgba(224,185,92,0.7)",
  },
  {
    key: "black",
    badge: "BLACK",
    amount: 120_000,
    perk: "Reservas prioritarias · premio a la 1ra visita",
    gradient: "linear-gradient(150deg, #14151F 0%, #23253A 55%, #40435E 100%)",
    badgeColor: "#C9CCE0",
    ringColor: "rgba(201,204,224,0.6)",
  },
  {
    key: "custom",
    badge: "PLATINUM",
    amount: null,
    perk: "Elegís el monto · concierge y mesa reservada",
    gradient: "linear-gradient(150deg, #1B1533 0%, #3A2A78 48%, #6E5AC8 100%)",
    badgeColor: "#D6CBFF",
    ringColor: "rgba(150,124,232,0.75)",
  },
];

/** Reference: `else if (n < 121000) customErr = "El mínimo es $121.000";` */
export const CUSTOM_AMOUNT_MIN = 121_000;
/** Reference: `else if (n > 1000000) customErr = "El máximo es $1.000.000";` */
export const CUSTOM_AMOUNT_MAX = 1_000_000;

/** Same `"$" + Math.round(n).toLocaleString("es-AR")` formatter used by both references (`const money = ...`). */
export function formatArs(amount: number): string {
  return `$${Math.round(amount).toLocaleString("es-AR")}`;
}
