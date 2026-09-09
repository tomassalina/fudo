"use client";

import { useMemo } from "react";
import { useSession } from "@/lib/session/use-session";
import { generateQrCells, formatConsumerQrId, QR_GRID_SIZE } from "@/lib/mock/qr-grid";

/**
 * "Mi QR" tab — a visually-faithful QR code placeholder (finder-pattern
 * corners + deterministic pseudo-random fill, see lib/mock/qr-grid.ts),
 * NOT a real scannable QR code. There's no `visits`/loyalty write endpoint
 * for a waiter's scanner to hit yet (see lib/api/README.md), so generating
 * one that actually encodes anything would be theatre — this renders the
 * same grid the design reference shows (`qrCells`/`QR`), which is honest
 * about being a mock: the visit is only ever really mocked, wherever it's
 * displayed.
 */
export function QrMyCodeTab() {
  const { consumer } = useSession();
  const cells = useMemo(() => generateQrCells(), []);

  if (!consumer) return null;

  const fullName = `${consumer.firstName} ${consumer.lastName}`.trim();
  const qrId = formatConsumerQrId(consumer.id);

  return (
    <div className="flex flex-col items-center pt-5">
      <div className="rounded-[26px] bg-white p-4.5 shadow-[0_18px_44px_rgba(0,0,0,0.45)]">
        <div
          className="grid"
          style={{
            gridTemplateColumns: `repeat(${QR_GRID_SIZE}, 9px)`,
            gridAutoRows: "9px",
          }}
        >
          {cells.map((on, index) => (
            <span
              key={index}
              className="rounded-[1px]"
              style={{ background: on ? "#14151F" : "transparent" }}
            />
          ))}
        </div>
      </div>

      <p className="pt-5 font-heading text-[19px] font-extrabold text-foreground">
        {fullName}
      </p>
      <p className="max-w-[260px] pt-1.5 text-center text-[13px] leading-relaxed text-foreground-muted">
        Mostrale este código al mesero para validar tu visita.
      </p>

      <div className="mt-3.5 flex items-center gap-2 rounded-full border border-border bg-surface px-3.5 py-2">
        <span aria-hidden className="material-symbols text-[17px] text-accent">
          badge
        </span>
        <span className="text-[12.5px] text-foreground-muted">ID {qrId}</span>
      </div>
    </div>
  );
}
