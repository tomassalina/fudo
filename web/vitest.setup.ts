// Adds jest-dom's extended matchers (toBeInTheDocument, toHaveAttribute, ...)
// to Vitest's `expect`, including the TypeScript ambient types.
import "@testing-library/jest-dom/vitest";

import { afterEach } from "vitest";
import { cleanup } from "@testing-library/react";

// React Testing Library normally auto-registers this via the test
// framework's global `afterEach`, but this project intentionally does not
// enable Vitest's `globals: true` (tests import `describe`/`it`/`expect`
// explicitly), so it must be wired up here instead — otherwise each
// rendered component leaks into the next test's DOM.
afterEach(() => {
  cleanup();
});
