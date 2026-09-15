import type { Metadata } from "next";
import { Space_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
  variable: "--font-space-grotesk",
  subsets: ["latin"],
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://symbians.app"),
  title: {
    default: "Symbians — Your AI Co-Pilot for Solana Trading",
    template: "%s | Symbians",
  },
  description:
    "Give your AI agent a strategy in plain English. Auto-execute swaps, limits, and perps on Solana.",
  keywords: ["Solana", "AI trading", "trading bot", "Jupiter", "perps", "DeFi", "crypto trading"],
  authors: [{ name: "Symbians" }],
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://symbians.app",
    siteName: "Symbians",
    title: "Symbians — AI Trading Agent for Solana",
    description: "Give it a strategy. Watch it trade.",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Symbians - AI Trading on Solana",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Symbians — Your AI Co-Pilot for Solana Trading",
    description: "Give it a strategy. Watch it trade.",
    images: ["/og-image.png"],
    creator: "@symbians_sol",
  },
  robots: {
    index: true,
    follow: true,
  },
  icons: {
    icon: "/brand/symbians_logo_nobg.png",
    apple: "/brand/symbians_logo_nobg.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${spaceGrotesk.variable} ${jetbrainsMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-bg text-text font-sans">
        {children}
      </body>
    </html>
  );
}
