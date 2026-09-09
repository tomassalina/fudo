/** "$13.000"-style peso formatting — shared between the merchant-detail
 * server page (SEO price-range text in generateMetadata) and its client view
 * (menu item prices), so the two can't drift apart. */
export function formatPrice(value: number) {
  return `$${value.toLocaleString("es-AR")}`;
}
