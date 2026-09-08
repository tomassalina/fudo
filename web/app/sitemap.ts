// Dynamic sitemap — part of the SEO infrastructure the PRD calls for
// ("que Google indexe cada restaurante"): lists the two static routes plus
// one entry per merchant detail page, generated from the same MOCK_MERCHANTS
// fixture generateStaticParams uses in app/restaurantes/[id]/page.tsx, so it
// never drifts from the actual set of statically generated merchant pages.

import type { MetadataRoute } from "next";
import { MOCK_MERCHANTS } from "@/lib/mock/merchants";
import { BASE_URL } from "@/lib/seo/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const staticRoutes: MetadataRoute.Sitemap = [
    {
      url: BASE_URL,
      changeFrequency: "weekly",
      priority: 1,
    },
    {
      url: `${BASE_URL}/buscar`,
      changeFrequency: "daily",
      priority: 0.9,
    },
  ];

  const merchantRoutes: MetadataRoute.Sitemap = MOCK_MERCHANTS.map(
    (merchant) => ({
      url: `${BASE_URL}/restaurantes/${merchant.id}`,
      changeFrequency: "weekly",
      priority: 0.8,
    }),
  );

  return [...staticRoutes, ...merchantRoutes];
}
