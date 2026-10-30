// Run once after adding your key:  npm run check:api
// Makes one Muse Spark call and one SAM 3.1 call on the sample picture and reports what came back.
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
const png = fs.readFileSync(path.join(here, "..", "public", "sample", "sample.png"));
const dataUrl = `data:image/png;base64,${png.toString("base64")}`;
const meta = createMeta({ apiKey: key, baseURL: process.env.MODEL_BASE_URL || undefined, sparkModel: process.env.SPARK_MODEL || undefined, samModel: process.env.SAM_MODEL || undefined });

try {
  console.log(`Muse Spark (${meta.sparkModel}) ...`);
  const d = await meta.describeParts(dataUrl);
  console.log("  title:", d.title, "| parts:", d.parts.map((p) => p.label).join(", "));
  const first = d.parts[0];
  console.log(`SAM 3.1 (${meta.samModel}) on "${first.label}" ...`);
  const seg = await meta.segment(dataUrl, first.label);
  console.log("  outcome:", seg.outcome.status, "| diagnostics:", seg.diagnostics.length);
  const regions = buildRegions({ part: first, partIndex: 0, records: seg.records, imgW: 800, imgH: 600 });
  console.log("  regions:", regions.map((r) => `${r.label} box=${r.box.join(",")} area=${r.area}`).join(" ; ") || "none");
  console.log("\nBoth models answered. If regions is empty, the label found no match: try the app with a different picture.");
} catch (err) {
  console.error("\nFAILED:", err?.status ?? "", err?.message ?? err);
  console.error("Check the key, the model names (SPARK_MODEL / SAM_MODEL) and https://dev.meta.ai/docs/error-handling");
  process.exit(1);
}
