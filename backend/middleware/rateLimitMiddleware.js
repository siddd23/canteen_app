const buckets = new Map();

const positiveInteger = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
};

const cleanupTimer = setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of buckets.entries()) {
    if (bucket.resetAt <= now) buckets.delete(key);
  }
}, 5 * 60 * 1000);
cleanupTimer.unref();

const createRateLimit = ({ windowMs, max, keyPrefix, message }) =>
  (req, res, next) => {
    const now = Date.now();
    const client = req.ip || req.socket.remoteAddress || "unknown";
    const key = `${keyPrefix}:${client}`;
    let bucket = buckets.get(key);

    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + windowMs };
      buckets.set(key, bucket);
    }

    bucket.count += 1;
    const remaining = Math.max(0, max - bucket.count);
    const retryAfterSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));

    res.setHeader("RateLimit-Limit", max);
    res.setHeader("RateLimit-Remaining", remaining);
    res.setHeader("RateLimit-Reset", Math.ceil(bucket.resetAt / 1000));

    if (bucket.count > max) {
      res.setHeader("Retry-After", retryAfterSeconds);
      return res.status(429).json({
        success: false,
        message,
        requestId: req.requestId,
      });
    }

    return next();
  };

const generalRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000,
  max: positiveInteger(process.env.GENERAL_RATE_LIMIT, 600),
  keyPrefix: "general",
  message: "Too many requests. Please try again shortly.",
});

// Authentication is rate-limited separately from ordinary employee API calls.
// Only rejected logins/signups consume the failure budget; success is not penalized.
const authRateLimit = (req, res, next) => {
  const max = positiveInteger(process.env.AUTH_RATE_LIMIT, 20);
  const windowMs = 15 * 60 * 1000;
  const now = Date.now();
  const realm = req.baseUrl === "/api/customers" ? "employee" : "owner";
  const key = `auth-failures:${realm}:${req.ip || req.socket.remoteAddress || "unknown"}`;
  let bucket = buckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    bucket = { count: 0, resetAt: now + windowMs };
    buckets.set(key, bucket);
  }
  const retryAfterSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
  res.setHeader("RateLimit-Limit", max);
  res.setHeader("RateLimit-Remaining", Math.max(0, max - bucket.count));
  res.setHeader("RateLimit-Reset", Math.ceil(bucket.resetAt / 1000));
  if (bucket.count >= max) {
    res.setHeader("Retry-After", retryAfterSeconds);
    return res.status(429).json({
      success: false,
      message: "Too many failed login or registration attempts. Please try again later.",
      requestId: req.requestId,
    });
  }
  res.once("finish", () => {
    // Do not penalize successful authentication or server-side failures.
    if (res.statusCode >= 400 && res.statusCode < 500 && res.statusCode !== 429) {
      bucket.count += 1;
    }
  });
  return next();
};

const publicOrderRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000,
  max: positiveInteger(process.env.PUBLIC_ORDER_RATE_LIMIT, 100),
  keyPrefix: "public-order",
  message: "Too many order requests. Please wait before trying again.",
});

module.exports = { generalRateLimit, authRateLimit, publicOrderRateLimit };
