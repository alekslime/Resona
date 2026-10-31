// Runs one local picture through the same steps as /api/analyze and shows what came back.
// Usage (from backend/):  node scripts/try-image.js path/to/picture.jpg
// It makes real API calls: one Spark call plus one SAM call per part.
import "dotenv/config";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { imageSize } from "image-size";
import { createMeta, mapLimit } from "../server/meta.js";
import { buildRegions } from "../server/regions.js";

const file = process.argv[2];
if (!file) {
  console.error("Usage: node scripts/try-image.js path/to/picture.jpg");
  process.exit(1);
}
const apiKey = process.env.MODEL_API_KEY;
if (!apiKey) {
  console.error("MODEL_API_KEY is not set. Copy .env.example to .env and add your key.");
  process.exit(1);
}

const buf = fs.readFileSync(file);
const { width: imgW, height: imgH } = imageSize(buf);
const mime = path.extname(file).toLowerCase() === ".png" ? "image/png" : "image/jpeg";
const dataUrl = `data:${mime};base64,${buf.toString("base64")}`;

const meta = createMeta({
  apiKey,
  baseURL: process.env.MODEL_BASE_URL,
  sparkModel: process.env.SPARK_MODEL,
  samModel: process.env.SAM_MODEL,
  effort: process.env.SPARK_REASONING_EFFORT,
});

console.log(`Picture ${imgW}x${imgH}. Asking ${meta.sparkModel} to name the parts...`);
const described = await meta.describeParts(dataUrl);
console.log(`\n${described.title} (${described.kind})\n${described.overview}\n`);
console.log("Parts named: " + described.parts.map((p) => p.label).join(" | ") + "\n");

const regions = [];
const missing = [];
const failed = [];
await mapLimit(described.parts, 3, async (part, i) => {
  try {
    const seg = await meta.segment(dataUrl, part.label);
    const found = buildRegions({ part, partIndex: i, records: seg.records, imgW, imgH });
    if (!found.length) missing.push(part.label);
    regions.push(...found);
  } catch (err) {
    failed.push(`${part.label} (${err?.message ?? err})`);
  }
});

regions.sort((a, b) => a.order - b.order);
for (const r of regions) {
  const pct = ((r.area / (imgW * imgH)) * 100).toFixed(1);
  console.log(`${String(r.order + 1).padStart(2)}. ${r.label} | ${pct}% of picture | box ${r.box.join(",")} | mask ${r.mask.w}x${r.mask.h}`);
}
if (missing.length) console.log(`\nSAM found nothing for: ${missing.join(", ")}`);
if (failed.length) console.log(`\nFailed: ${failed.join("; ")}`);

const json = JSON.stringify(regions).replace(/</g, "\\u003c");
const html = `<!doctype html><meta charset="utf-8"><title>try-image</title>
<style>
body{font:14px system-ui;margin:16px}
.wrap{position:relative;display:inline-block;max-width:100%}
img{display:block;max-width:100%}
canvas{position:absolute;image-rendering:pixelated;opacity:.6}
.tag{position:absolute;background:#000;color:#fff;font-size:12px;padding:1px 4px;white-space:nowrap}
</style>
<div class="wrap"><img src="${dataUrl}"><div id="layer"></div></div>
<script>
var W=${imgW},H=${imgH},regions=${json},layer=document.getElementById("layer");
regions.forEach(function(r){
  var c=document.createElement("canvas");c.width=r.mask.w;c.height=r.mask.h;
  var ctx=c.getContext("2d"),img=ctx.createImageData(r.mask.w,r.mask.h);
  var bits=Uint8Array.from(atob(r.mask.b64),function(ch){return ch.charCodeAt(0);});
  for(var i=0;i<bits.length;i++){if(bits[i]){img.data[i*4]=255;img.data[i*4+1]=90;img.data[i*4+2]=31;img.data[i*4+3]=255;}}
  ctx.putImageData(img,0,0);
  var b=r.box,l=b[0]/W*100+"%",t=b[1]/H*100+"%";
  c.style.left=l;c.style.top=t;c.style.width=(b[2]-b[0])/W*100+"%";c.style.height=(b[3]-b[1])/H*100+"%";
  layer.appendChild(c);
  var tag=document.createElement("div");tag.className="tag";tag.textContent=r.label;tag.style.left=l;tag.style.top=t;
  layer.appendChild(tag);
});
</script>`;
const out = path.join(os.tmpdir(), `resonant-try-${Date.now()}.html`);
fs.writeFileSync(out, html);
console.log(`\nOverlay (open in a browser): ${out}`);