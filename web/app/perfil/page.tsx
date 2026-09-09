// Thin page shell — all the real UI/logic lives in PerfilView (a client
// component, since it needs session state, router redirects and local edit
// state), same split as app/login/page.tsx + LoginForm.

import type { Metadata } from "next";
import { PerfilView } from "@/components/features/perfil/PerfilView";

export const metadata: Metadata = {
  title: "Perfil — Fudo",
  description: "Tu historial de visitas, recompensas y datos de cuenta en Fudo.",
};

export default function PerfilPage() {
  return <PerfilView />;
}
