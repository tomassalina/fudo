"use client"; // Error boundaries must be Client Components (Next.js error.js convention).

import { useEffect } from "react";

// Catches failures from the real search request (network down, timeout,
// non-2xx from the backend) once NEXT_PUBLIC_API_BASE_URL is set — see
// lib/api/README.md. Never triggers with the default mock-backed data
// layer, which doesn't throw. `error.message` is scrubbed by Next.js in
// production for Server Component errors, so this intentionally shows one
// generic, non-technical message rather than trying to branch on it.
export default function BuscarError({
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
    <main className="mx-auto flex w-full max-w-5xl flex-1 flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      <p className="font-heading text-lg font-bold text-foreground">
        No pudimos cargar la búsqueda
      </p>
      <p className="max-w-sm text-[13px] text-foreground-muted">
        Puede ser un problema temporal de conexión. Probá de nuevo en un
        momento.
      </p>
      <button
        type="button"
        onClick={retry}
        className="rounded-full bg-accent-soft px-4 py-2 text-[13px] font-semibold text-accent-light"
      >
        Reintentar
      </button>
    </main>
  );
}
