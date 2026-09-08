// Minimal typed fetch wrapper for the Rails backend.
//
// TODO: replace with the real base URL / auth strategy once the Rails
// backend contract exists (e.g. env-based base URL, auth headers/cookies,
// error shape). This is a placeholder stub, not a finished API client.

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

export async function apiFetch<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, init);

  if (!response.ok) {
    throw new Error(`API request failed: ${response.status} ${path}`);
  }

  return response.json() as Promise<T>;
}
