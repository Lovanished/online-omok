import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "오목 온라인",
  description: "친구와 실시간으로 즐기는 온라인 오목",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
