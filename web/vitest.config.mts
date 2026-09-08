import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "node:path";

const rootDir = import.meta.dirname;

// Vitest config for this Next.js 16 App Router project (no `src/`).
// Kept separate from next.config.ts / tsconfig's build pipeline — this file
// is never imported by the Next.js app graph, so it has no effect on
// `next build` or `next dev`; it only configures the `vitest` CLI.
//
// jsdom (not happy-dom) per Next.js's own current Vitest guide
// (node_modules/next/dist/docs/01-app/02-guides/testing/vitest.md).
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      // Mirrors tsconfig.json's "@/*" -> "./*" path mapping.
      "@": path.resolve(rootDir, "."),
    },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    // Keep this scoped to the __tests__ tree so it never wanders into
    // node_modules, .next, or non-test source files.
    include: ["__tests__/**/*.test.{ts,tsx}"],
    exclude: ["node_modules/**", ".next/**"],
  },
});
