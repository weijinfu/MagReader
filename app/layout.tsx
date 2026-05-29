import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MagReader",
  description: "A local-first English article reader for language learners."
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
