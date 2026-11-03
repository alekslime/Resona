// Run once after adding your key:  npm run check:api
// Makes one Muse Spark call on the sample picture and reports what came back.
import "dotenv/config";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createMeta } from "../server/meta.js";
import { buildRegions } from "../server/regions.js";

const key = process.env.MODEL_API_KEY;
if (!key) {
  console.error("MODEL_API_KEY is not set. Copy .env.example to .env and add your key.");
  process.exit(1);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const png = fs.readFileSync(path.join(here, "..", "sample", "sample.png"));
const dataUrl = `data:image/png;base64,${png.toString("base64")}`;
const meta = createMeta({ apiKey: key, baseURL: process.env.MODEL_BASE_URL || undefined, sparkModel: process.env.SPARK_MODEL || undefined });

try {
  console.log(`Muse Spark (${meta.sparkModel}) ...`);
  const d = await meta.describeParts(dataUrl);
  console.log("  title:", d.title, "| parts:", d.parts.map((p) => p.label).join(", "));
  const regions = d.parts.flatMap((part, partIndex) => buildRegions({ part, partIndex, imgW: 800, imgH: 600 }));
  console.log("  regions:", regions.map((r) => `${r.label} box=${r.box.join(",")} area=${r.area}`).join(" ; ") || "none");
  console.log("\nSpark answered. If regions is empty, no part had a usable box: try the app with a different picture.");
} catch (err) {
  console.error("\nFAILED:", err?.status ?? "", err?.message ?? err);
  console.error("Check the key, the model name (SPARK_MODEL) and https://dev.meta.ai/docs/error-handling");
  process.exit(1);
}
