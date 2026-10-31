// LiveKit room tokens, minted by hand (an HS256 JWT) so the backend needs no
// extra dependency and the LiveKit secret never leaves this server.
// The picture context (title, overview, the part under the student's finger)
// rides inside the token as participant metadata, where the agent reads it.
import crypto from "node:crypto";

const b64url = (buf) =>
  Buffer.from(buf).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

export function liveKitConfig(env = process.env) {
  const url = env.LIVEKIT_URL;
  const apiKey = env.LIVEKIT_API_KEY;
  const apiSecret = env.LIVEKIT_API_SECRET;
  return url && apiKey && apiSecret ? { url, apiKey, apiSecret } : null;
}

export function mintLiveKitToken({ apiKey, apiSecret }, { identity, room, name, metadata }) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(
    JSON.stringify({
      iss: apiKey,
      sub: identity,
      name: name ?? identity,
      metadata: metadata ?? "",
      iat: now,
      nbf: now,
      exp: now + 60 * 60, // one hour is plenty for a study session
      jti: `${identity}-${now}`,
      video: {
        roomJoin: true,
        room,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      },
    }),
  );
  const sig = b64url(crypto.createHmac("sha256", apiSecret).update(`${header}.${payload}`).digest());
  return `${header}.${payload}.${sig}`;
}

/** Validate + clamp the picture context a client sends for the tutor. */
export function liveKitSession(cfg, body) {
  const identity = `student-${crypto.randomBytes(4).toString("hex")}`;
  const room = `resonant-${crypto.randomBytes(4).toString("hex")}`;
  const clamp = (v, n) => String(v ?? "").slice(0, n);
  const metadata = JSON.stringify({
    title: clamp(body?.title, 200),
    overview: clamp(body?.overview, 1000),
    regionLabel: clamp(body?.regionLabel, 200),
    regionSpoken: clamp(body?.regionSpoken, 400),
    regionDetail: clamp(body?.regionDetail, 900),
  });
  const token = mintLiveKitToken(cfg, { identity, room, name: "student", metadata });
  return { url: cfg.url, token, room, identity };
}
