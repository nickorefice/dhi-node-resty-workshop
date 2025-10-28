import express, { Request, Response } from "express";
import path from "path";

const app = express();
const PORT = 3000;

// Serve static files from public directory
app.use(express.static(path.join(__dirname, "../public")));

// Health check endpoint
app.get("/api/health", (_req: Request, res: Response) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Time formatting endpoint - demonstrates Full ICU support
app.get("/api/time", (req: Request, res: Response) => {
  const locale = (req.query.locale as string) || "en-US";
  const tz = (req.query.tz as string) || "UTC";

  try {
    const now = new Date();

    // This demonstrates Full ICU capabilities
    // Without full-icu, many locales and timezones would fail
    const formatted = new Intl.DateTimeFormat(locale, {
      dateStyle: "full",
      timeStyle: "long",
      timeZone: tz
    }).format(now);

    // Additional ICU demo: number formatting
    const numberFormatted = new Intl.NumberFormat(locale, {
      style: "currency",
      currency: getCurrencyForLocale(locale)
    }).format(12345.67);

    res.json({
      locale,
      tz,
      formatted,
      numberExample: numberFormatted,
      timestamp: now.toISOString(),
      icuDataPath: process.env.NODE_ICU_DATA || "built-in"
    });
  } catch (error) {
    res.status(400).json({
      error: "Invalid locale or timezone",
      message: error instanceof Error ? error.message : String(error)
    });
  }
});

// Helper function to get currency code from locale
function getCurrencyForLocale(locale: string): string {
  const currencyMap: Record<string, string> = {
    "en-US": "USD",
    "en-GB": "GBP",
    "fr-FR": "EUR",
    "de-DE": "EUR",
    "ja-JP": "JPY",
    "zh-CN": "CNY",
    "es-ES": "EUR",
    "it-IT": "EUR",
    "pt-BR": "BRL",
    "ko-KR": "KRW"
  };
  return currencyMap[locale] || "USD";
}

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`ICU data path: ${process.env.NODE_ICU_DATA || "built-in"}`);
  console.log(`Node version: ${process.version}`);
});
