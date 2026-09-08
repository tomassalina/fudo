import type { Metadata } from "next";
import { Barlow, Inter } from "next/font/google";
import { Header } from "@/components/layout/Header";
import "./globals.css";

// Typography per the design reference: Barlow (heavy weights) for headings,
// Inter for body/UI text.
const barlow = Barlow({
  variable: "--font-barlow",
  subsets: ["latin"],
  weight: ["700", "800", "900"],
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Fudo Consumers",
  description:
    "Encontrá donde comer. Ganá descuentos por cada visita — buscá restaurantes, bares y cafés en Palermo.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="es"
      className={`${barlow.variable} ${inter.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <Header />
        {children}
      </body>
    </html>
  );
}
