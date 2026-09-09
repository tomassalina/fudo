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
 * Registration form. The design reference has no dedicated "Registro"
 * screen — its "Registrate" link just triggers the same mock login state
 * (`login: () => this.setState({ user: "martina" })` in both dc.html
 * files). Fields are instead drawn from the one place the reference *does*
 * collect a consumer's personal info as plain inputs: the edit-profile form
 * (`eFirst`/`eLast`/`eEmail`/`ePhone`, "Nombre"/"Apellido"/"Email"/
 * "Teléfono" placeholders) — reusing its exact input styling via
 * AuthShell/authInputClassName. A password field is added since this form
 * has to double as account creation.
 *
 * DNI is deliberately NOT collected here: per design.md Decision 1, the DNI
 * is loaded by the waiter at checkout, not typed in by the consumer at
 * signup — the design reference only ever shows it as a masked, read-only
 * profile field ("•••• 4821"), never as an editable input. This used to be
 * a real conflict with the backend (`Consumer` required `dni` presence,
 * confirmed with a live curl returning `422 {"errors":{"dni":["can't be
 * blank"]}}` on any registration with no `dni`) — fixed backend-side
 * (commit 1cdb20e, `dni` is now optional on `POST /api/v1/registrations`,
 * re-confirmed live: `201` + a real JWT with no `dni` in the payload), so
 * this form staying DNI-less is now correct per Decision 1, not a
 * known gap.
 *
 * Calls the real `POST /api/v1/registrations` (via `useSession().register`,
 * session-provider.tsx) — a `password`/`password_confirmation` mismatch or a
 * duplicate email surface as a real 422 from the backend, rendered via
 * `error.message` below.
 */
export function RegisterForm() {
  const router = useRouter();
  const { register } = useSession();
  const isPhone = useIsPhoneViewport();

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (firstName.trim().length === 0) {
      setError("Ingresá tu nombre.");
      return;
    }
    if (lastName.trim().length === 0) {
      setError("Ingresá tu apellido.");
      return;
    }
    if (!isValidEmail(email)) {
      setError("Ingresá un email válido.");
      return;
    }
    if (phone.trim().length === 0) {
      setError("Ingresá tu teléfono.");
      return;
    }
    if (password.trim().length === 0) {
      setError("Creá una contraseña.");
      return;
    }

    setError(null);
    setSubmitting(true);
    try {
      await register({
        email: email.trim(),
        password,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
      });
      router.push("/perfil");
    } catch (error) {
      setError(error instanceof Error ? error.message : "Ocurrió un error. Intentá de nuevo.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <AuthShell
      heading="Creá tu cuenta"
      subtitle="Sumate a Fudo y empezá a ganar recompensas"
      footer={
        <>
          ¿Ya tenés cuenta?{" "}
          <Link
            href="/login"
            className="font-semibold text-accent hover:text-accent-light"
          >
            Iniciá sesión
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit} noValidate className="flex w-full flex-col gap-3">
        <input
          type="text"
          autoComplete="given-name"
          placeholder="Nombre"
          aria-label="Nombre"
          value={firstName}
          onChange={(event) => setFirstName(event.target.value)}
          className={authInputClassName(isPhone)}
        />
        <input
          type="text"
          autoComplete="family-name"
          placeholder="Apellido"
          aria-label="Apellido"
          value={lastName}
          onChange={(event) => setLastName(event.target.value)}
          className={authInputClassName(isPhone)}
        />
        <input
          type="email"
          autoComplete="email"
          placeholder="Email"
          aria-label="Email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className={authInputClassName(isPhone)}
        />
        <input
          type="tel"
          autoComplete="tel"
          placeholder="Teléfono"
          aria-label="Teléfono"
          value={phone}
          onChange={(event) => setPhone(event.target.value)}
          className={authInputClassName(isPhone)}
        />
        <input
          type="password"
          autoComplete="new-password"
          placeholder="Creá una contraseña"
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
          {submitting ? "Creando cuenta…" : "Crear cuenta"}
        </Button>
      </form>
    </AuthShell>
  );
}
