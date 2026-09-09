"use client";

// Escaneo de cámara real: placeholder visual, sin integración de cámara en
// esta fase. Mirrors the "Escaneá el QR del local" viewfinder from the
// design reference (`qrScanning`, corner brackets + moving scan line via the
// `fudoScan` keyframe already registered in app/globals.css) — no
// `navigator.mediaDevices` call anywhere here, on purpose.
export function QrScanTab() {
  return (
    <div className="flex flex-col items-center pt-5">
      <div className="relative h-[236px] w-[236px] overflow-hidden rounded-[26px] bg-[#0C0D14]">
        <span
          aria-hidden
          className="absolute inset-0"
          style={{
            background:
              "repeating-linear-gradient(45deg, rgba(255,255,255,0.02) 0 10px, rgba(255,255,255,0.05) 10px 20px)",
          }}
        />
        {(
          [
            ["top-4 left-4", "border-t-[3px] border-l-[3px] rounded-tl-xl"],
            ["top-4 right-4", "border-t-[3px] border-r-[3px] rounded-tr-xl"],
            ["bottom-4 left-4", "border-b-[3px] border-l-[3px] rounded-bl-xl"],
            ["bottom-4 right-4", "border-b-[3px] border-r-[3px] rounded-br-xl"],
          ] as const
        ).map(([position, border]) => (
          <span
            key={position}
            aria-hidden
            className={`absolute h-[34px] w-[34px] border-accent ${position} ${border}`}
          />
        ))}
        <span
          aria-hidden
          className="absolute left-[10%] right-[10%] h-0.5 animate-fudo-scan"
          style={{
            background:
              "linear-gradient(90deg, transparent, #FF5023, transparent)",
            boxShadow: "0 0 18px rgba(255,80,35,0.8)",
          }}
        />
      </div>

      <p className="pt-5 font-heading text-[19px] font-extrabold text-foreground">
        Escaneá el QR del local
      </p>
      <p className="max-w-[250px] pt-1.5 text-center text-[13px] leading-relaxed text-foreground-muted">
        Se suma la visita y aplicamos tu descuento al instante.
      </p>
    </div>
  );
}
