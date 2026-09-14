const test = require("node:test");
const assert = require("node:assert/strict");

const { validateEnvironment } = require("../config/environment");

const variableNames = [
  "NODE_ENV",
  "APP_BASE_URL",
  "MONGODB_URI",
  "JWT_SECRET",
  "SUPER_ADMIN_EMAIL",
  "SUPER_ADMIN_PASSWORD",
  "CORS_ORIGINS",
];

const originalValues = Object.fromEntries(
  variableNames.map((name) => [name, process.env[name]]),
);

test.afterEach(() => {
  for (const name of variableNames) {
    const value = originalValues[name];
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
});

test("development accepts the required configuration", () => {
  process.env.NODE_ENV = "development";
  process.env.MONGODB_URI = "mongodb://127.0.0.1/test";
  process.env.JWT_SECRET = "development-secret";
  process.env.SUPER_ADMIN_EMAIL = "admin@example.com";
  process.env.SUPER_ADMIN_PASSWORD = "password";
  assert.doesNotThrow(validateEnvironment);
});

test("production rejects weak secrets", () => {
  process.env.NODE_ENV = "production";
  process.env.APP_BASE_URL = "https://api.example.com";
  process.env.MONGODB_URI = "mongodb://127.0.0.1/test";
  process.env.JWT_SECRET = "short";
  process.env.SUPER_ADMIN_EMAIL = "admin@example.com";
  process.env.SUPER_ADMIN_PASSWORD = "strong-password";
  process.env.CORS_ORIGINS = "https://app.example.com";
  assert.throws(validateEnvironment, /JWT_SECRET/);
});

test("production accepts strong secrets and an origin allowlist", () => {
  process.env.NODE_ENV = "production";
  process.env.APP_BASE_URL = "https://api.example.com";
  process.env.MONGODB_URI = "mongodb://127.0.0.1/test";
  process.env.JWT_SECRET = "a-secure-random-secret-with-32-characters";
  process.env.SUPER_ADMIN_EMAIL = "admin@example.com";
  process.env.SUPER_ADMIN_PASSWORD = "strong-password";
  process.env.CORS_ORIGINS = "https://app.example.com";
  assert.doesNotThrow(validateEnvironment);
});

test("production rejects insecure public URLs", () => {
  process.env.NODE_ENV = "production";
  process.env.APP_BASE_URL = "http://api.example.com";
  process.env.MONGODB_URI = "mongodb://127.0.0.1/test";
  process.env.JWT_SECRET = "a-secure-random-secret-with-32-characters";
  process.env.SUPER_ADMIN_EMAIL = "admin@example.com";
  process.env.SUPER_ADMIN_PASSWORD = "strong-password";
  process.env.CORS_ORIGINS = "https://app.example.com";
  assert.throws(validateEnvironment, /APP_BASE_URL/);
});
