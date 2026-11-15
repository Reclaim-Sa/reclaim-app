import "./globals.css";

export const metadata = {
  title: "RECLAIM",
  description: "Take control. Reclaim your life.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
