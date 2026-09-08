// robots.txt — allows all crawlers everywhere and points them at the sitemap.
// Using the .ts convention (not a static public/robots.txt) so the sitemap
// URL always matches BASE_URL in app/sitemap.ts instead of being hand-typed
// twice.

import type { MetadataRoute } from "next";
import { BASE_URL } from "@/lib/seo/site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    sitemap: `${BASE_URL}/sitemap.xml`,
  };
}
