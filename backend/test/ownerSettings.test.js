const test = require("node:test");
const assert = require("node:assert/strict");

const Owner = require("../models/Owner");

test("new owners receive safe default order preferences", () => {
  const owner = new Owner({
    name: "Test Owner",
    businessName: "Test Canteen",
    email: "owner@example.com",
    mobile: "9876543210",
    password: "secure-password",
  });

  assert.equal(owner.preferences.orderSoundEnabled, true);
  assert.equal(owner.preferences.payLaterEnabled, true);
  assert.equal(owner.preferences.defaultPreparationTime, 15);
  assert.equal(owner.toJSON().password, undefined);
});
