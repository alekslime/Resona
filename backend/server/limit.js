// Tiny in-memory rate limiter so a public demo can't burn through the API
// credits. Bounded: every request sweeps entries older than the window, and
// the table never holds more than maxKeys IPs, so a flood of distinct
// addresses cannot grow memory without end.
export function createLimiter({ max, windowMs, maxKeys = 1000, now = Date.now }) {
  const hits = new Map();
  const sweep = (at) => {
    for (const [key, times] of hits) {
      const recent = times.filter((t) => at - t < windowMs);
      if (recent.length) hits.set(key, recent);
      else hits.delete(key);
    }
  };
  const middleware = (req, res, next) => {
    const at = now();
    sweep(at);
    const recent = hits.get(req.ip) ?? [];
    if (recent.length >= max) {
      res.set("Retry-After", String(Math.ceil(windowMs / 1000)));
      return res.status(429).json({ error: "Too many requests. Wait a minute and try again." });
    }
    recent.push(at);
    hits.set(req.ip, recent);
    while (hits.size > maxKeys) hits.delete(hits.keys().next().value);
    next();
  };
  // Entries currently tracked, for tests and ops. Never exceeds maxKeys.
  middleware.size = () => hits.size;
  return middleware;
}
