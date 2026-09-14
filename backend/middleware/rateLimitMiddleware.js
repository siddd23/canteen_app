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

const authRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000,
  max: positiveInteger(process.env.AUTH_RATE_LIMIT, 20),
  keyPrefix: "auth",
  message: "Too many login or registration attempts. Please try again later.",
});

const publicOrderRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000,
  max: positiveInteger(process.env.PUBLIC_ORDER_RATE_LIMIT, 100),
  keyPrefix: "public-order",
  message: "Too many order requests. Please wait before trying again.",
});

module.exports = { generalRateLimit, authRateLimit, publicOrderRateLimit };
