/**
 * The four destinations shared by both nav layouts (phone bottom pill, wide
 * sticky top bar) — same keys/icons as `tabDefs` in the design reference
 * (`Fudo App.dc.html` / `Fudo Customers.dc.html`).
 *
 * Split the same way the reference splits `tabsLeft` / `tabsRight` around
 * the QR action: Inicio + Buscar on one side, Regalar (+ Perfil, gated) on
 * the other.
 */
export type NavItemDef = {
  key: string;
  label: string;
  /** Material Symbols Outlined glyph name. */
  icon: string;
  href: string;
};

export const NAV_LEFT: readonly NavItemDef[] = [
  { key: "inicio", label: "Inicio", icon: "home", href: "/" },
  { key: "buscar", label: "Buscar", icon: "search", href: "/buscar" },
];

/**
 * Regalar is always visible; Perfil only renders once there's a session —
 * see `(st.user ? tabDefs.slice(2) : [tabDefs[2]])` in
 * Fudo Customers.dc.html. Callers filter this list by `useSession()` instead
 * of baking the gate in here, so both nav layouts apply it identically.
 */
export const NAV_RIGHT: readonly NavItemDef[] = [
  { key: "regalar", label: "Regalar", icon: "redeem", href: "/regalar" },
  { key: "perfil", label: "Perfil", icon: "person", href: "/perfil" },
];

export function visibleNavRight(isAuthenticated: boolean): NavItemDef[] {
  return isAuthenticated ? [...NAV_RIGHT] : NAV_RIGHT.filter((item) => item.key !== "perfil");
}
