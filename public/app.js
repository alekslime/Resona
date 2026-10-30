import { prepareRegions, hitRegion, nearestRegion, hapticMs, readingOrder } from "./hit.js";

const $ = (id) => document.getElementById(id);
const screens = { start: $("start"), busy: $("busy"), explore: $("explore") };
const canvas = $("canvas");
const ctx = canvas.getContext("2d");

const state = {
  prepared: null, // { dataUrl, source (canvas), width, height }
  data: null, // /api/analyze response
  regions: [],
  highlight: null,
  last: null, // last region touched, used as context for Ask
  rate: Number(localStorage.getItem("ta-rate")) || 1.1,
};
$("rate").value = state.rate;
$("rate").addEventListener("input", (e) => {
  state.rate = Number(e.target.value);
  localStorage.setItem("ta-rate", String(state.rate));
  say("Speech speed set.");
});

/* ---------- speech and haptics ---------- */

function say(text, { queue = false } = {}) {
  $("caption").textContent = text;
  if (!("speechSynthesis" in window)) return;
  if (!queue) speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.rate = state.rate;
  speechSynthesis.speak(u);
}
const buzz = (pattern) => navigator.vibrate?.(pattern);

function show(name) {
  for (const [key, el] of Object.entries(screens)) el.hidden = key !== name;
}

/* ---------- picking a picture ---------- */

async function prepareImage(blob) {
  const bmp = await createImageBitmap(blob);
  const scale = Math.min(1, 1280 / Math.max(bmp.width, bmp.height));
  const width = Math.round(bmp.width * scale);
  const height = Math.round(bmp.height * scale);
  const source = document.createElement("canvas");
  source.width = width;
  source.height = height;
  source.getContext("2d").drawImage(bmp, 0, 0, width, height);
  return { source, width, height, dataUrl: source.toDataURL("image/jpeg", 0.88) };
}

async function analyze(file) {
  show("busy");
  say("Reading the picture. This takes about half a minute.");
  const keepAlive = setInterval(() => { buzz(30); say("Still working.", { queue: true }); }, 12000);
  try {
    const prepared = await prepareImage(file);
    const res = await fetch("/api/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ image: prepared.dataUrl }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || "Something went wrong. Try again.");
    enterExplore(data, prepared);
  } catch (err) {
    show("start");
    $("startNote").textContent = err.message;
    say(err.message);
  } finally {
    clearInterval(keepAlive);
  }
}

async function loadSample() {
  try {
    const [data, blob] = await Promise.all([
      fetch("sample/sample.json").then((r) => r.json()),
      fetch("sample/sample.png").then((r) => r.blob()),
    ]);
    enterExplore(data, await prepareImage(blob));
  } catch {
    $("startNote").textContent = "The sample picture could not be loaded.";
  }
}

$("file").addEventListener("change", (e) => {
  const file = e.target.files?.[0];
  e.target.value = "";
  if (file) analyze(file);
});
$("sample").addEventListener("click", loadSample);
$("again").addEventListener("click", () => {
  speechSynthesis?.cancel();
  state.highlight = state.last = null;
  show("start");
  $("startNote").textContent = "";
});

/* ---------- exploring ---------- */

function enterExplore(data, prepared) {
  state.data = data;
  state.prepared = prepared;
  state.regions = prepareRegions(data.regions, data.width, data.height);
  state.highlight = state.last = null;
  buildPartsList();
  show("explore");
  layout();
  const note = data.synthetic ? " This is a sample. Its outlines were drawn by hand, not by the model." : "";
  say(`${data.title}. ${state.regions.length} parts found. Drag a finger over the picture.${note}`);
}

function buildPartsList() {
  const list = $("partsList");
  list.replaceChildren();
  for (const r of readingOrder(state.regions)) {
    const li = document.createElement("li");
    const b = document.createElement("button");
    b.type = "button";
    b.className = "btn";
    b.textContent = r.label;
    b.addEventListener("click", () => {
      state.highlight = state.last = r;
      draw();
      buzz(hapticMs(r));
      say(`${r.label}. ${r.detail}`);
    });
    li.append(b);
    list.append(li);
  }
}

const sil = new Map(); // cached coloured silhouettes of each mask
function silhouette(region, rgb) {
  const key = `${region.id}|${rgb}`;
  if (sil.has(key)) return sil.get(key);
  const c = document.createElement("canvas");
  c.width = region.mask.w;
  c.height = region.mask.h;
  const cx = c.getContext("2d");
  const img = cx.createImageData(c.width, c.height);
  const [r, g, b] = rgb.split(",").map(Number);
  for (let i = 0; i < region.bits.length; i++) {
    if (region.bits[i]) img.data.set([r, g, b, 255], i * 4);
  }
  cx.putImageData(img, 0, 0);
  sil.set(key, c);
  return c;
}

function layout() {
  if (!state.prepared) return;
  const stage = $("stage");
  const availW = stage.clientWidth - 12;
  const availH = stage.clientHeight - 12;
  const { width: W, height: H } = state.prepared;
  const fit = Math.min(availW / W, availH / H);
  if (!(fit > 0)) return;
  const dpr = window.devicePixelRatio || 1;
  canvas.style.width = `${Math.floor(W * fit)}px`;
  canvas.style.height = `${Math.floor(H * fit)}px`;
  canvas.width = Math.floor(W * fit * dpr);
  canvas.height = Math.floor(H * fit * dpr);
  draw();
}
new ResizeObserver(layout).observe($("stage"));

function draw() {
  if (!state.prepared) return;
  const { source, width: W, height: H } = state.prepared;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
  const r = state.highlight;
  if (!r) return;
  const sx = canvas.width / W;
  const sy = canvas.height / H;
  const [l, t, rt, b] = r.box;
  const x = l * sx, y = t * sy, w = (rt - l) * sx, h = (b - t) * sy;
  const dpr = window.devicePixelRatio || 1;
  ctx.imageSmoothingEnabled = true;
  // Two-tone halo (dark then white) so the outline reads on any picture, then a tint inside.
  const halo = (rgb, radius) => {
    const s = silhouette(r, rgb);
    for (let k = 0; k < 16; k++) {
      const a = (k * Math.PI) / 8;
      ctx.drawImage(s, x + Math.cos(a) * radius * dpr, y + Math.sin(a) * radius * dpr, w, h);
    }
  };
  halo("12,27,38", 6);
  halo("255,255,255", 3.5);
  ctx.globalAlpha = 0.5;
  ctx.drawImage(silhouette(r, "214,36,110"), x, y, w, h);
  ctx.globalAlpha = 1;
}

/* ---------- touch ---------- */

let focus = null, enterTimer = 0, dwellTimer = 0, lastTap = 0, downAt = 0, downPos = null, wasInside = false;

function toPicture(e) {
  const rect = canvas.getBoundingClientRect();
  const { width: W, height: H } = state.prepared;
  const x = ((e.clientX - rect.left) / rect.width) * W;
  const y = ((e.clientY - rect.top) / rect.height) * H;
  return { x, y, inside: x >= 0 && y >= 0 && x < W && y < H };
}

function onTouch(e) {
  if (!state.prepared) return;
  const p = toPicture(e);
  if (!p.inside) {
    if (wasInside) { buzz([8, 30, 8, 30, 8]); say("Edge of the picture."); }
    wasInside = false;
    focus = null;
    return;
  }
  wasInside = true;
  const r = hitRegion(state.regions, p.x, p.y, state.prepared.width * 0.006);
  if (r !== focus) {
    clearTimeout(enterTimer);
    const previous = focus;
    focus = r;
    if (r) {
      state.highlight = state.last = r;
      draw();
      buzz(hapticMs(r));
      enterTimer = setTimeout(() => say(r.label), 110);
    } else {
      if (previous) buzz([8, 30, 8]);
      speechSynthesis?.cancel();
      $("caption").textContent = "";
    }
  }
  clearTimeout(dwellTimer);
  dwellTimer = setTimeout(() => {
    if (focus) return say(focus.spoken, { queue: true });
    const near = nearestRegion(state.regions, p.x, p.y);
    if (near) say(`Nothing here. ${near.region.label} is ${near.words}.`);
  }, focus ? 800 : 1100);
}

canvas.addEventListener("pointerdown", (e) => {
  e.preventDefault();
  canvas.setPointerCapture(e.pointerId);
  downAt = performance.now();
  downPos = { x: e.clientX, y: e.clientY };
  onTouch(e);
});
canvas.addEventListener("pointermove", (e) => { if (e.buttons || e.pressure > 0) onTouch(e); });
const release = (e) => {
  clearTimeout(dwellTimer);
  const quick = performance.now() - downAt < 300;
  const still = downPos && Math.hypot(e.clientX - downPos.x, e.clientY - downPos.y) < 14;
  if (quick && still) {
    const now = performance.now();
    if (now - lastTap < 450 && state.last) say(`${state.last.label}. ${state.last.detail}`); // double tap
    lastTap = now;
  }
  focus = null;
  wasInside = false;
};
canvas.addEventListener("pointerup", release);
canvas.addEventListener("pointercancel", release);
canvas.addEventListener("contextmenu", (e) => e.preventDefault());

/* ---------- buttons ---------- */

$("overview").addEventListener("click", () => {
  state.highlight = null;
  draw();
  say(`${state.data.title}. ${state.data.overview}`);
});
$("partsBtn").addEventListener("click", () => {
  const names = readingOrder(state.regions).map((r) => r.label);
  say(`${names.length} parts: ${names.join(", ")}.`);
});

/* ---------- ask ---------- */

const dlg = $("askDialog");
$("askBtn").addEventListener("click", () => {
  $("answer").textContent = "";
  dlg.showModal();
  $("question").focus();
});
$("askCancel").addEventListener("click", () => dlg.close());

async function ask(question) {
  $("answer").textContent = "Thinking.";
  try {
    const res = await fetch("/api/ask", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        image: state.prepared.dataUrl,
        question,
        title: state.data.title,
        regionLabel: state.last?.label ?? "",
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || "Something went wrong. Try again.");
    $("answer").textContent = data.answer;
    say(data.answer);
  } catch (err) {
    $("answer").textContent = err.message;
    say(err.message);
  }
}
$("askForm").addEventListener("submit", (e) => {
  e.preventDefault();
  const q = $("question").value.trim();
  if (q) ask(q);
});

const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
if (Recognition) {
  const mic = $("mic");
  mic.hidden = false;
  mic.addEventListener("click", () => {
    const rec = new Recognition();
    rec.lang = document.documentElement.lang || "en-US";
    rec.onresult = (ev) => {
      $("question").value = ev.results[0][0].transcript;
      ask($("question").value);
    };
    rec.onerror = () => { $("answer").textContent = "The microphone is not available here. Type your question instead."; };
    speechSynthesis?.cancel();
    rec.start();
  });
}
