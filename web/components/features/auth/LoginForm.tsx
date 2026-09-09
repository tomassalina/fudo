"use client";

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useSession } from "@/lib/session/use-session";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { Button } from "@/components/ui/Button";
import { AuthShell } from "./AuthShell";
import { authInputClassName } from "./auth-field-styles";
import { isValidEmail } from "@/lib/utils/validation";

/**
 * Login form — email + password only, per
 * openspec/changes/fudo-consumers-mvp/design.md Decision 9 ("El MVP soporta
 * únicamente login con email y contraseña. No hay Google OAuth"). The design
 * reference's "Continuar con Google" button and "o con email" divider are
 * intentionally left out for that reason.
 *
 * Mock rule (no real backend to check credentials against): any
 * syntactically valid email + a non-empty password succeeds — see the TODO
 * in lib/session/session-provider.tsx. The only "invalid credentials" this
 * form can actually show is a client-side format error.
 */
export function LoginForm() {
  const router = useRouter();
  const { login } = useSession();
  const isPhone = useIsPhoneViewport();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!isValidEmail(email)) {
      setError("Ingresá un email válido.");
      return;
    }
    if (password.trim().length === 0) {
      setError("Ingresá tu contraseña.");
      return;
    }

    setError(null);
    setSubmitting(true);
    try {
      await login(email, password);
      router.push("/perfil");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <AuthShell
      heading="Bienvenido"
      subtitle="Ingresá a tu cuenta de Fudo"
      footer={
        <>
          ¿No tenés cuenta?{" "}
          <Link
            href="/registro"
            className="font-semibold text-accent hover:text-accent-light"
          >
            Registrate
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit} noValidate className="flex w-full flex-col gap-3">
        <input
          type="email"
          autoComplete="email"
          placeholder="tu@email.com"
          aria-label="Email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className={authInputClassName(isPhone)}
        />
        <input
          type="password"
          autoComplete="current-password"
          placeholder="Tu contraseña"
          aria-label="Contraseña"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className={authInputClassName(isPhone)}
        />

        {error ? (
          <p role="alert" className="text-[13px] text-accent-light">
            {error}
          </p>
        ) : null}

        <Button type="submit" size="lg" disabled={submitting} className="w-full">
          {submitting ? "Ingresando…" : "Iniciar sesión"}
        </Button>
      </form>
    </AuthShell>
  );
}
