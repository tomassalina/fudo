"use client"; // Error boundaries must be Client Components (Next.js error.js convention).

import { useEffect } from "react";
import Link from "next/link";

// Catches failures from the real merchant-detail request (network down,
// timeout, non-2xx from the backend) once NEXT_PUBLIC_API_BASE_URL is set —
// see lib/api/README.md. A merchant that genuinely doesn't exist (a real
// 404) is handled separately via notFound(), not here. Never triggers with
// the default mock-backed data layer, which doesn't throw. `error.message`
// is scrubbed by Next.js in production for Server Component errors, so
// this intentionally shows one generic, non-technical message rather than
// trying to branch on it.
export default function MerchantError({
  error,
  retry,
}: {
  error: Error & { digest?: string };
  retry: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      <p className="font-heading text-lg font-bold text-foreground">
        No pudimos cargar este restaurante
      </p>
      <p className="max-w-sm text-[13px] text-foreground-muted">
        Puede ser un problema temporal de conexión. Probá de nuevo en un
        momento.
      </p>
      <div className="flex gap-2">
        <button
          type="button"
          onClick={retry}
          className="rounded-full bg-accent-soft px-4 py-2 text-[13px] font-semibold text-accent-light"
        >
          Reintentar
        </button>
        <Link
          href="/buscar"
          className="rounded-full border border-border px-4 py-2 text-[13px] font-semibold text-foreground"
        >
          Volver a la búsqueda
        </Link>
      </div>
    </main>
  );
}
