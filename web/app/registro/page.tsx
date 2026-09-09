// Thin page shell — all the real UI/logic lives in RegisterForm (a client
// component, since it needs form state and useSession()).

import type { Metadata } from "next";
import { RegisterForm } from "@/components/features/auth/RegisterForm";

export const metadata: Metadata = {
  title: "Creá tu cuenta — Fudo",
  description: "Sumate a Fudo y empezá a ganar recompensas en tus restaurantes favoritos.",
};

export default function RegistroPage() {
  return <RegisterForm />;
}
