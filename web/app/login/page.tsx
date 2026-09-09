// Thin page shell — all the real UI/logic lives in LoginForm (a client
// component, since it needs form state and useSession()).

import type { Metadata } from "next";
import { LoginForm } from "@/components/features/auth/LoginForm";

export const metadata: Metadata = {
  title: "Iniciar sesión — Fudo",
  description: "Ingresá a tu cuenta de Fudo para sumar recompensas en cada visita.",
};

export default function LoginPage() {
  return <LoginForm />;
}
