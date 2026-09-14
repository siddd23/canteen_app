const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const mongoose = require("mongoose");

const { getAllowedOrigins } = require("./config/environment");
const requestContext = require("./middleware/requestContextMiddleware");
const {
  generalRateLimit,
  authRateLimit,
  publicOrderRateLimit,
} = require("./middleware/rateLimitMiddleware");

const {
  notFound,
  errorHandler,
} = require("./middleware/errorMiddleware");
const authRoutes = require("./routes/authRoutes");
const ownerRoutes = require("./routes/ownerRoutes");
const canteenRoutes = require("./routes/canteenRoutes");
const officeRoutes = require("./routes/officeRoutes");
const menuRoutes = require("./routes/menuRoutes");
const publicOrderingRoutes = require("./routes/publicOrderingRoutes");
const orderRoutes = require("./routes/orderRoutes");
const accountRoutes = require("./routes/accountRoutes");
const sessionRoutes = require("./routes/sessionRoutes");
const app = express();

app.disable("x-powered-by");

if (process.env.TRUST_PROXY) {
  app.set("trust proxy", Number(process.env.TRUST_PROXY));
}

app.use(requestContext);
app.use(helmet());

const allowedOrigins = getAllowedOrigins();
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || process.env.NODE_ENV !== "production") {
        return callback(null, true);
      }

      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      const error = new Error("Origin is not allowed by CORS policy");
      error.statusCode = 403;
      return callback(error);
    },
    credentials: true,
    methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Request-Id"],
    exposedHeaders: ["X-Request-Id", "Retry-After"],
    maxAge: 86400,
  })
);

app.use(express.json({ limit: "10kb" }));
app.use(express.urlencoded({ extended: true, limit: "10kb" }));

morgan.token("safe-url", (req) =>
  req.originalUrl.replace(/([?&]token=)[^&]+/gi, "$1[REDACTED]"),
);
const accessLogFormat = process.env.NODE_ENV === "production"
  ? ':remote-addr - :remote-user [:date[clf]] ":method :safe-url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent"'
  : ":method :safe-url :status :response-time ms - :res[content-length]";
app.use(morgan(accessLogFormat));

app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Canteen App backend is running",
  });
});

app.get("/api/health", (req, res) => {
  const databaseReady = mongoose.connection.readyState === 1;
  res.status(databaseReady ? 200 : 503).json({
    success: databaseReady,
    status: databaseReady ? "ready" : "not_ready",
    database: databaseReady ? "connected" : "disconnected",
    environment: process.env.NODE_ENV,
    uptimeSeconds: Math.floor(process.uptime()),
    requestId: req.requestId,
    timestamp: new Date().toISOString(),
  });
});

app.use(generalRateLimit);
app.use("/api/auth", authRateLimit, authRoutes);
app.use("/api/session", sessionRoutes);
app.use("/api/admin/owners", ownerRoutes);
app.use("/api/canteens", canteenRoutes);
app.use("/api/canteens", menuRoutes);
app.use("/api/offices", officeRoutes);
app.use("/api/public", publicOrderRateLimit, publicOrderingRoutes);
app.use("/api/orders", orderRoutes);
app.use("/api/account", accountRoutes);
/*
 * API routes will be registered here:
 *
 * app.use("/api/auth", authRoutes);
 * app.use("/api/admin/owners", ownerRoutes);
 * app.use("/api/canteens", canteenRoutes);
 */

app.use(notFound);
app.use(errorHandler);

module.exports = app;
