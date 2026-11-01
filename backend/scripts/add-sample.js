// Bakes a gallery extra: analyzes an image once (paid) and commits its
// outlines, so every judge after opens it instantly and for free.
// The backend must be running locally with a Meta API key.
// Usage: npm run sample:add -- ./lungs.png lungs
//        BASE=http://127.0.0.1:3000 npm run sample:add -- ./map.png transit-map
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const sampleDir = path.join(here, "..", "sample");

const [imagePath, id] = process.argv.slice(2);
if (!imagePath || !id) {
  console.error("Usage: npm run sample:add -- <picture.png> <id>");
  process.exit(1);
}
if (!/^[a-z0-9-]{1,40}$/.test(id)) {
  console.error("Id must be 1-40 lowercase letters, digits or dashes.");
  process.exit(1);
}
if (!imagePath.toLowerCase().endsWith(".png")) {
  console.error("Save the picture as PNG first: the gallery serves <id>.png beside <id>.json.");
  process.exit(1);
}
let bytes;
try {
  bytes = fs.readFileSync(imagePath);
} catch {
  console.error(`Cannot read ${imagePath}.`);
  process.exit(1);
}
if (bytes.length > 8 * 1024 * 1024) {
  console.error("That picture is over 8 MB. Shrink it first.");
  process.exit(1);
}

const base = process.env.BASE ?? "http://127.0.0.1:3000";
const res = await fetch(`${base}/api/analyze`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ image: `data:image/png;base64,${bytes.toString("base64")}` }),
});
const data = await res.json().catch(() => ({}));
if (!res.ok) {
  console.error(data.error ?? `The server answered ${res.status}. Is it running with a key?`);
  process.exit(1);
}
fs.copyFileSync(imagePath, path.join(sampleDir, `${id}.png`));
fs.writeFileSync(path.join(sampleDir, `${id}.json`), JSON.stringify(data, null, 1) + "\n");
console.log(`Baked ${id}: ${data.regions.length} regions. It appears in GET /api/samples now.`);
console.log("Backend extras stay backend-only: commit sample/ and redeploy, no app changes needed.");
