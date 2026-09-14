const test = require("node:test");
const assert = require("node:assert/strict");

process.env.NODE_ENV = "test";
const app = require("../app");

test("health endpoint reports database readiness and a request ID", async () => {
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));

  try {
    const address = server.address();
    const response = await fetch(`http://127.0.0.1:${address.port}/api/health`);
    const body = await response.json();

    assert.equal(response.status, 503);
    assert.equal(body.status, "not_ready");
    assert.equal(body.database, "disconnected");
    assert.ok(response.headers.get("x-request-id"));
    assert.equal(body.requestId, response.headers.get("x-request-id"));
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("tracking endpoint rejects malformed credentials before database access", async () => {
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));

  try {
    const address = server.address();
    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/public/orders/INVALID/track?token=secret`,
    );
    const body = await response.json();

    assert.equal(response.status, 400);
    assert.equal(body.success, false);
    assert.ok(body.requestId);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("account settings endpoint requires owner authentication", async () => {
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));

  try {
    const address = server.address();
    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/account/profile`,
    );
    const body = await response.json();
    assert.equal(response.status, 401);
    assert.equal(body.success, false);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("session restoration endpoint requires a valid saved token", async () => {
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));

  try {
    const address = server.address();
    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/session`,
    );
    const body = await response.json();
    assert.equal(response.status, 401);
    assert.equal(body.success, false);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
