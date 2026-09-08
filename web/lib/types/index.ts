// Placeholder data types for the Fudo Consumers sub-platform.
//
// TODO: reconcile with docs/database-schema.png once shared / with the real
// Rails schema. Field names and types here are minimal, safe guesses (id,
// name, description/price) — not a verified contract with the backend.

export interface Merchant {
  id: string;
  name: string;
  description?: string;
}

export interface MenuItem {
  id: string;
  name: string;
  description?: string;
  price?: number;
}
