"use client";

import { useContext } from "react";
import { SessionContext, type SessionContextValue } from "./session-provider";

export type {
  Consumer,
  ConsumerProfileInput,
  ConsumerUpdateInput,
  SessionContextValue,
} from "./session-provider";

/**
 * Real session accessor, backed by `SessionProvider`
 * (lib/session/session-provider.tsx, mounted once in app/layout.tsx) instead
 * of the earlier hardcoded `{ isAuthenticated: false }` stub.
 *
 * Returns the full session shape (consumer, isAuthenticated, login, logout,
 * updateProfile) — a superset of the old `{ isAuthenticated: boolean }`
 * return, so existing
 * call sites that only destructure `isAuthenticated` (PhoneNav, WideNav,
 * RegalarPage) keep working unchanged.
 */
export function useSession(): SessionContextValue {
  const context = useContext(SessionContext);
  if (!context) {
    throw new Error("useSession must be used within a SessionProvider");
  }
  return context;
}
