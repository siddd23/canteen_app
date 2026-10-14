const {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const Canteen = require("../models/Canteen");
const Owner = require("../models/Owner");

const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

let firebaseReady;
let configurationWarningShown = false;

const resolveCredential = () => {
  const encoded = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (encoded) {
    const serviceAccount = JSON.parse(
      Buffer.from(encoded, "base64").toString("utf8"),
    );
    return cert(serviceAccount);
  }

  const inline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (inline) return cert(JSON.parse(inline));

  return applicationDefault();
};

const ensureFirebase = () => {
  if (firebaseReady !== undefined) return firebaseReady;

  try {
    if (getApps().length === 0) {
      initializeApp({ credential: resolveCredential() });
    }
    firebaseReady = true;
  } catch (error) {
    firebaseReady = false;
    if (!configurationWarningShown) {
      configurationWarningShown = true;
      console.warn(`Push notifications are disabled: ${error.message}`);
    }
  }

  return firebaseReady;
};

const sendNewOrderPush = async (order) => {
  if (!ensureFirebase()) return { sent: 0, skipped: true };

  // Resolve ownership from the canteen selected at checkout. Do not broadcast
  // or trust a caller-supplied owner when choosing notification recipients.
  const canteen = await Canteen.findById(order.canteenId)
    .select("ownerId")
    .lean();
  if (!canteen?.ownerId) return { sent: 0, skipped: true };

  const targetOwnerId = canteen.ownerId;
  if (String(order.ownerId) !== String(targetOwnerId)) {
    console.error(
      `Skipped push for ${order.orderNumber}: order owner does not match canteen owner`,
    );
    return { sent: 0, skipped: true };
  }

  const owner = await Owner.findById(targetOwnerId).select("+fcmTokens").lean();
  const tokens = [...new Set(owner?.fcmTokens || [])].slice(0, 500);
  if (tokens.length === 0) return { sent: 0, skipped: true };

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    data: {
      type: "new_order",
      orderId: String(order._id),
      orderNumber: String(order.orderNumber),
      canteenId: String(order.canteenId),
      fulfillmentType: String(order.fulfillmentType || "asap"),
      scheduledFor: order.scheduledFor ? order.scheduledFor.toISOString() : "",
      scheduledSlot: String(order.scheduledSlot || ""),
    },
    android: {
      priority: "high",
      ttl: 60 * 60 * 1000,
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: {
            title: "New BookFood order",
            body: `${order.orderNumber} from ${order.customerName}`,
          },
          sound: "default",
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  });

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (!result.success && invalidTokenCodes.has(result.error?.code)) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await Owner.findByIdAndUpdate(targetOwnerId, {
      $pull: { fcmTokens: { $in: invalidTokens } },
    });
  }

  return {
    sent: response.successCount,
    failed: response.failureCount,
  };
};

module.exports = { sendNewOrderPush };
