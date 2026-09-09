"use client";

import { useState } from "react";
import { cn } from "@/lib/utils/cn";
import type { Consumer } from "@/lib/session/use-session";
import { formatConsumerQrId } from "@/lib/mock/qr-grid";
import { useNotificationsSetting } from "@/lib/consumer-settings/use-notifications-setting";

/**
 * "Ajustes" tab — Perfil's `pConfig` view (`docs/design-reference/Fudo
 * App.dc.html`: `dataRows`, `prefRows`, `resetPass`/`deleteAccount`, lines
 * ~746-807). What's real vs. UI-only here, and why:
 *
 * - Nombre/Email/Teléfono/DNI/Alta + "Actualizar mis datos": reads
 *   `consumer` from the real session and opens the same `EditProfileForm`
 *   sheet PerfilView already wires up via `onEdit` — but see that form's own
 *   doc comment: there is no `PATCH /api/v1/consumers/:id` (or `/me`) route
 *   anywhere in `backend/config/routes.rb` at all (confirmed absent), so
 *   saving there is still local-only, not a real limitation of THIS tab.
 * - Notificaciones: **real** — `useNotificationsSetting()`
 *   (lib/consumer-settings/use-notifications-setting.ts) reads/writes the
 *   actual `ConsumerSetting.notifications_enabled` column via
 *   `backend/app/controllers/api/v1/consumer_settings_controller.rb`, now
 *   that there's a real bearer token to authenticate with.
 * - Alertas de precio: still **UI-only, local state** — that field doesn't
 *   exist on `ConsumerSetting` at all (confirmed against
 *   `backend/app/models/consumer_setting.rb`: only `theme` and
 *   `notifications_enabled`), so there's nothing real to persist it to.
 * - The design's "Tema claro/oscuro" toggle is intentionally NOT
 *   reproduced: this app has no light theme to switch to (`app/globals.css`
 *   only ever defines the dark palette) — a toggle with nothing to toggle
 *   would be worse than no toggle. `ConsumerSetting.theme` exists on the
 *   backend but has no UI here for the same reason.
 * - "DNI · Verificado y cifrado": real-ish — reflects whether *this*
 *   consumer actually has a `dni` on file. Always "Pendiente" today: the
 *   `ConsumerBlueprint` used by login/registro never returns `dni`
 *   (deliberately excludes encrypted PII — see session-provider.tsx's
 *   `Consumer` doc comment), so the client never actually sees it even for
 *   a consumer who has one on file server-side.
 * - "Enviar link" (password reset) and "Eliminar mi cuenta": **UI-only**.
 *   Neither `POST /api/v1/passwords` (or similar) nor any consumer-destroy
 *   route exists in `backend/config/routes.rb` at all — confirmed absent,
 *   not just unauthenticated. Both render a confirmation state and stop
 *   there; deleting never actually signs the consumer out or removes
 *   anything, so the label says so explicitly instead of silently doing
 *   nothing (or, worse, faking a real deletion via `logout()`).
 * - "Cerrar sesión": real — the same `logout()` + redirect PerfilView always
 *   had (now backed by a real session, see session-provider.tsx), just
 *   relocated here to match the design's "SEGURIDAD Y CUENTA" grouping
 *   instead of living outside every tab.
 */

function formatMaskedDni(dni: string | undefined): string {
  if (!dni) return "Pendiente";
  const last4 = dni.replace(/\D/g, "").slice(-4).padStart(4, "•");
  return `•••• ${last4}`;
}

// Short Spanish month abbreviations, matching the design's own "Alta" copy
// ("12 mar 2025") — `Intl.DateTimeFormat("es-AR", { month: "short" })`
// inserts "de" ("12 de mar. de 2025"), which the design never does.
const MONTHS_ES = [
  "ene",
  "feb",
  "mar",
  "abr",
  "may",
  "jun",
  "jul",
  "ago",
  "sep",
  "oct",
  "nov",
  "dic",
];

function formatMemberSince(createdAt: string | undefined): string {
  if (!createdAt) return "—";
  const date = new Date(createdAt);
  if (Number.isNaN(date.getTime())) return "—";
  return `${date.getDate()} ${MONTHS_ES[date.getMonth()]} ${date.getFullYear()}`;
}

interface DataRow {
  icon: string;
  label: string;
  value: string;
}

function DataRows({ rows }: { rows: DataRow[] }) {
  return (
    <div className="flex flex-col rounded-[16px] border border-border bg-surface">
      {rows.map((row, index) => (
        <div
          key={row.label}
          className={cn(
            "flex items-center gap-2.5 px-3 py-3",
            index < rows.length - 1 && "border-b border-border",
          )}
        >
          <span aria-hidden className="material-symbols text-[19px] text-foreground-faint">
            {row.icon}
          </span>
          <span className="flex-none text-[13.5px] text-foreground-muted">{row.label}</span>
          <span className="flex-1 truncate text-right text-[13.5px] text-foreground">
            {row.value}
          </span>
        </div>
      ))}
    </div>
  );
}

function ToggleRow({
  icon,
  label,
  on,
  onToggle,
}: {
  icon: string;
  label: string;
  on: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="flex items-center justify-between border-b border-border px-3 py-3 last:border-b-0">
      <div className="flex items-center gap-2.5">
        <span aria-hidden className="material-symbols text-[20px] text-foreground-muted">
          {icon}
        </span>
        <span className="text-[14px] text-foreground">{label}</span>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-label={label}
        onClick={onToggle}
        className={cn(
          "flex h-[27px] w-[46px] items-center rounded-full p-[3px] transition-colors duration-200",
          on ? "justify-end bg-accent" : "justify-start bg-surface-2",
        )}
      >
        <span className="h-[21px] w-[21px] rounded-full bg-white" />
      </button>
    </div>
  );
}

export interface SettingsTabProps {
  consumer: Consumer;
  onEdit: () => void;
  onLogout: () => void;
}

export function SettingsTab({ consumer, onEdit, onLogout }: SettingsTabProps) {
  const { notificationsEnabled, toggleNotifications } = useNotificationsSetting();
  const [priceAlerts, setPriceAlerts] = useState(false);
  const [resetLinkSent, setResetLinkSent] = useState(false);
  const [deleteArmed, setDeleteArmed] = useState(false);
  const [deleteBlocked, setDeleteBlocked] = useState(false);

  const fullName = `${consumer.firstName} ${consumer.lastName}`.trim();
  const dniVerified = Boolean(consumer.dni);

  function handleDeleteClick() {
    if (!deleteArmed) {
      setDeleteArmed(true);
      return;
    }
    // Confirmed twice, but there is no real account-deletion endpoint on
    // the backend (see the header comment) — surface that honestly instead
    // of pretending anything happened.
    setDeleteBlocked(true);
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h3 className="pb-2.5 text-[11px] font-bold uppercase tracking-[0.1em] text-foreground-faint">
          Datos personales
        </h3>
        <DataRows
          rows={[
            { icon: "badge", label: "Nombre", value: fullName },
            { icon: "mail", label: "Email", value: consumer.email },
            { icon: "call", label: "Teléfono", value: consumer.phone || "Sin cargar" },
            { icon: "fingerprint", label: "DNI", value: formatMaskedDni(consumer.dni) },
            { icon: "event", label: "Alta", value: formatMemberSince(consumer.createdAt) },
          ]}
        />
        <button
          type="button"
          onClick={onEdit}
          className="mt-2.5 flex w-full items-center gap-2.5 rounded-full border border-border bg-surface px-4 py-3 text-left transition-colors hover:border-accent/50"
        >
          <span aria-hidden className="material-symbols text-[18px] text-accent">
            edit
          </span>
          <span className="flex-1 text-[13.5px] font-semibold text-foreground">
            Actualizar mis datos
          </span>
          <span aria-hidden className="material-symbols text-[18px] text-foreground-faint">
            chevron_right
          </span>
        </button>
      </div>

      <div>
        <h3 className="pb-2.5 text-[11px] font-bold uppercase tracking-[0.1em] text-foreground-faint">
          Preferencias
        </h3>
        <div className="flex flex-col rounded-[16px] border border-border bg-surface">
          <ToggleRow
            icon="notifications"
            label="Notificaciones"
            on={notificationsEnabled}
            onToggle={toggleNotifications}
          />
          <ToggleRow
            icon="sell"
            label="Alertas de precio"
            on={priceAlerts}
            onToggle={() => setPriceAlerts((value) => !value)}
          />
          <div className="flex items-center gap-2.5 px-3 py-3">
            <span aria-hidden className="material-symbols text-[20px] text-foreground-muted">
              verified_user
            </span>
            <span className="flex-1 text-[14px] text-foreground">DNI</span>
            <span
              className={cn(
                "rounded-full px-2.5 py-1 text-[12px] font-bold",
                dniVerified
                  ? "bg-success-soft text-success"
                  : "bg-surface-2 text-foreground-faint",
              )}
            >
              {dniVerified ? "Verificado y cifrado" : "Pendiente"}
            </span>
          </div>
        </div>
      </div>

      <div>
        <h3 className="pb-2.5 text-[11px] font-bold uppercase tracking-[0.1em] text-foreground-faint">
          Seguridad y cuenta
        </h3>
        <div className="flex flex-col rounded-[16px] border border-border bg-surface">
          <button
            type="button"
            onClick={() => setResetLinkSent(true)}
            disabled={resetLinkSent}
            className="flex w-full items-center gap-2.5 border-b border-border px-3 py-3.5 text-left disabled:cursor-default"
          >
            <span aria-hidden className="material-symbols text-[20px] text-foreground-muted">
              lock_reset
            </span>
            <span className="flex-1 text-[14px] text-foreground">Restablecer contraseña</span>
            <span
              className={cn(
                "text-[12.5px]",
                resetLinkSent ? "text-success" : "text-foreground-faint",
              )}
            >
              {resetLinkSent ? "Link enviado ✓" : "Enviar link"}
            </span>
          </button>
          <button
            type="button"
            onClick={onLogout}
            className="flex w-full items-center gap-2.5 border-b border-border px-3 py-3.5 text-left"
          >
            <span aria-hidden className="material-symbols text-[20px] text-foreground-muted">
              logout
            </span>
            <span className="flex-1 text-[14px] text-foreground">Cerrar sesión</span>
          </button>
          <button
            type="button"
            onClick={handleDeleteClick}
            disabled={deleteBlocked}
            className="flex w-full items-center gap-2.5 px-3 py-3.5 text-left disabled:cursor-default"
          >
            <span aria-hidden className="material-symbols text-[20px] text-accent">
              delete_forever
            </span>
            <span className="flex-1 text-[14px] text-accent-light">
              {deleteBlocked
                ? "Pendiente de backend — tu cuenta no fue eliminada"
                : deleteArmed
                  ? "Tocá de nuevo para confirmar"
                  : "Eliminar mi cuenta"}
            </span>
          </button>
        </div>
      </div>

      <p className="px-0.5 text-[11.5px] leading-relaxed text-foreground-faint">
        Miembro desde {formatMemberSince(consumer.createdAt)} · ID{" "}
        {formatConsumerQrId(consumer.id)}
      </p>
    </div>
  );
}
