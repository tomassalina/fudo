const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Minimal client-side UI validation — good enough to catch obviously
 * malformed input before submit, not a substitute for server-side
 * validation once this talks to a real backend.
 */
export function isValidEmail(value: string): boolean {
  return EMAIL_PATTERN.test(value);
}
