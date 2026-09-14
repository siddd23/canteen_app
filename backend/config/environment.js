const requiredVariables = [
  "MONGODB_URI",
  "JWT_SECRET",
  "SUPER_ADMIN_EMAIL",
  "SUPER_ADMIN_PASSWORD",
];

const isValidUrl = (value, allowedProtocols) => {
  try {
    const url = new URL(value);
    return allowedProtocols.includes(url.protocol) && Boolean(url.hostname);
  } catch (_) {
    return false;
  }
};

const validateEnvironment = () => {
  const missing = requiredVariables.filter(
    (name) => !process.env[name] || !process.env[name].trim(),
  );

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
  }

  const environment = process.env.NODE_ENV || "development";
  const allowedEnvironments = ["development", "test", "production"];
  if (!allowedEnvironments.includes(environment)) {
    throw new Error("NODE_ENV must be development, test, or production");
  }

  if (environment === "production") {
    if (process.env.JWT_SECRET.length < 32) {
      throw new Error("JWT_SECRET must contain at least 32 characters in production");
    }

    if (process.env.SUPER_ADMIN_PASSWORD.length < 12) {
      throw new Error(
        "SUPER_ADMIN_PASSWORD must contain at least 12 characters in production",
      );
    }

    if (!process.env.CORS_ORIGINS) {
      throw new Error("CORS_ORIGINS is required in production");
    }

    if (!process.env.APP_BASE_URL ||
        !isValidUrl(process.env.APP_BASE_URL, ["https:"])) {
      throw new Error("APP_BASE_URL must be a valid HTTPS URL in production");
    }

    if (!isValidUrl(process.env.MONGODB_URI, ["mongodb:", "mongodb+srv:"])) {
      throw new Error("MONGODB_URI must be a valid MongoDB connection URL");
    }

    const invalidOrigins = getAllowedOrigins().filter(
      (origin) => !isValidUrl(origin, ["https:"]),
    );
    if (invalidOrigins.length > 0) {
      throw new Error("Every CORS_ORIGINS entry must be a valid HTTPS origin");
    }
  }
};

const getAllowedOrigins = () =>
  (process.env.CORS_ORIGINS || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

module.exports = { validateEnvironment, getAllowedOrigins };
