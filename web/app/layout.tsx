import type { Metadata } from "next";
import { Suspense } from "react";
import { Barlow, Inter } from "next/font/google";
import { AppNav } from "@/components/layout/nav/AppNav";
import { SessionProvider } from "@/lib/session/session-provider";
import { PostHogProvider } from "@/components/analytics/PostHogProvider";
import { PostHogPageview } from "@/components/analytics/PostHogPageview";
import "./globals.css";

// Typography per the design reference: Barlow (heavy weights, incl. the
// italic cut used for the "Ganá descuentos" emphasis) for headings, Inter
// for body/UI text. The reference's Google Fonts import requests exactly
// normal 600/700/800/900 + italic 900 (`Barlow:ital,wght@0,600;0,700;0,800;
// 0,900;1,900`); next/font/google can't request an asymmetric weight/style
// matrix in one call, so this fetches italic for every weight too — a
// harmless superset (same family/variable, no extra component to wire up)
// rather than splitting into two font objects for one unused axis point.
const barlow = Barlow({
  variable: "--font-barlow",
  subsets: ["latin"],
  weight: ["600", "700", "800", "900"],
  style: ["normal", "italic"],
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Fudo Consumers",
  description:
    "Encontrá dónde comer. Ganá descuentos por cada visita — buscá restaurantes, bares y cafés en Palermo.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="es"
      className={`${barlow.variable} ${inter.variable} h-full antialiased`}
    >
      <head>
        {/* Material Symbols Outlined — the exact icon font the design
            reference uses for every glyph (location pins, delivery, chat,
            reward, etc.). Loaded the same way the reference does: a plain
            Google Fonts stylesheet (not in next/font's curated Google set).
            The axis spec MUST use `min..max` ranges (Google's documented
            recommended range for this family), not single fixed points —
            the CSS2 API silently downgrades a single-point spec (e.g.
            `@24,200,0,0`) to a STATIC font instance frozen at those exact
            values, so any component that later sets a different
            `fontVariationSettings` (e.g. FILL:1 to fill a favorited heart)
            has no glyph to render against and gets no visual effect. */}
        {/* eslint-disable-next-line @next/next/no-page-custom-font -- this rule targets the Pages Router's _document.js; the App Router's root layout *is* the once-per-app shell, so it applies here on every page already. */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200&display=swap"
        />
      </head>
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <SessionProvider>
          <PostHogProvider>
            {/* useSearchParams requires a Suspense boundary so prerendered
                routes aren't forced into fully client-side rendering. */}
            <Suspense fallback={null}>
              <PostHogPageview />
            </Suspense>
            <AppNav />
            {children}
          </PostHogProvider>
        </SessionProvider>
      </body>
    </html>
  );
}
