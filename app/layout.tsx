import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "CampusConnect — Beyond your campus",
  description: "Your people, your communities, your next opportunity. A cross-college student network.",
  robots: { index: false, follow: false },
};
export default function RootLayout({children}:{children:React.ReactNode}) {
  return <html lang="en"><body>{children}</body></html>;
}
