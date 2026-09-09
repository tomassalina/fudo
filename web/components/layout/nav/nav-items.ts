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
 * Regalar is always visible. Perfil's visibility differs by layout: `WideNav`
 * hides it entirely while logged out (see `visibleNavRight`, mirroring
 * `(st.user ? tabDefs.slice(2) : [tabDefs[2]])` in Fudo Customers.dc.html) —
 * it already shows a separate "Iniciar sesión" CTA button instead. `PhoneNav`
 * keeps the 5th slot always visible and swaps it for a login prompt instead
 * (see `phoneNavRight`), since the bottom nav has no other login entry point.
 */
export const NAV_RIGHT: readonly NavItemDef[] = [
  { key: "regalar", label: "Regalar", icon: "redeem", href: "/regalar" },
  { key: "perfil", label: "Perfil", icon: "person", href: "/perfil" },
];

export function visibleNavRight(isAuthenticated: boolean): NavItemDef[] {
  return isAuthenticated ? [...NAV_RIGHT] : NAV_RIGHT.filter((item) => item.key !== "perfil");
}

/**
 * Logged-out stand-in for the Perfil tab, used only where the 5th slot must
 * stay visible with or without a session (the phone bottom nav — see the
 * reference screenshot this fixes). Same `key` as Perfil so `isActiveHref`
 * keeps working, but points at `/login` with a "walk through the door"
 * glyph instead of the profile icon.
 */
const LOGIN_ITEM: NavItemDef = {
  key: "perfil",
  label: "Ingresar",
  icon: "login",
  href: "/login",
};

/**
 * Phone bottom nav's right-hand items: Regalar plus a 5th slot that's
 * *always* present, unlike {@link visibleNavRight} (used by `WideNav`,
 * which already has a separate "Iniciar sesión" CTA button and so hides the
 * Perfil link entirely while logged out). Swaps to {@link LOGIN_ITEM} when
 * there's no session instead of disappearing, so the bottom nav always has
 * 5 icons at a fixed layout — see `PhoneNav.tsx`.
 */
export function phoneNavRight(isAuthenticated: boolean): NavItemDef[] {
  return isAuthenticated ? [...NAV_RIGHT] : [NAV_RIGHT[0], LOGIN_ITEM];
}
