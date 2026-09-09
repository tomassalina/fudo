"use client";

import { useState, type FormEvent } from "react";
import { useSession, type Consumer } from "@/lib/session/use-session";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { Sheet } from "@/components/ui/Sheet";
import { Button } from "@/components/ui/Button";
import { authInputClassName } from "@/components/features/auth/auth-field-styles";
import { isValidEmail } from "@/lib/utils/validation";

export interface EditProfileFormProps {
  open: boolean;
  onClose: () => void;
}

/**
 * "Actualizar mis datos" sheet — the design reference's `editOpen` dialog
 * (`eFirst`/`eLast`/`eEmail`/`ePhone` state, both dc.html files). Reuses the
 * generic `Sheet` shell (same one AppNav's QR sheet uses) instead of a
 * second bespoke modal, and the same input treatment as
 * LoginForm/RegisterForm via `authInputClassName` — both already-established
 * patterns from slice 1, not new ones invented for this form.
 *
 * On save, calls `updateProfile()` (session-provider.tsx) — a small,
 * deliberate addition to SessionProvider rather than re-calling `login()`:
 * `login()` mints a brand-new mocked consumer (new random `id`) every call,
 * which is correct for "signing in" but wrong for "editing the current
 * session" — it would silently change the consumer's identity on every save.
 *
 * The actual field state lives in `EditProfileFields` below, mounted only
 * while `open` (Sheet renders `null` and drops its children while closed —
 * see components/ui/Sheet.tsx) so each open reseeds fresh from the current
 * consumer via a plain `useState` initializer, no reset-on-prop-change
 * effect required.
 */
export function EditProfileForm({ open, onClose }: EditProfileFormProps) {
  const { consumer } = useSession();

  return (
    <Sheet open={open} onClose={onClose} title="Actualizar mis datos">
      {open && consumer ? (
        <EditProfileFields consumer={consumer} onClose={onClose} />
      ) : null}
    </Sheet>
  );
}

function EditProfileFields({
  consumer,
  onClose,
}: {
  consumer: Consumer;
  onClose: () => void;
}) {
  const { updateProfile } = useSession();
  const isPhone = useIsPhoneViewport();

  const [firstName, setFirstName] = useState(consumer.firstName);
  const [lastName, setLastName] = useState(consumer.lastName);
  const [email, setEmail] = useState(consumer.email);
  const [phone, setPhone] = useState(consumer.phone ?? "");
  const [error, setError] = useState<string | null>(null);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
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

    updateProfile({
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
      phone: phone.trim() || undefined,
    });
    onClose();
  }

  return (
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

      {error ? (
        <p role="alert" className="text-[13px] text-accent-light">
          {error}
        </p>
      ) : null}

      <Button type="submit" size="lg" className="mt-1 w-full">
        Guardar cambios
      </Button>
    </form>
  );
}
