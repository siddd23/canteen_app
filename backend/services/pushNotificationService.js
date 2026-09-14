const {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
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

  const owner = await Owner.findById(order.ownerId).select("+fcmTokens").lean();
  const tokens = [...new Set(owner?.fcmTokens || [])].slice(0, 500);
  if (tokens.length === 0) return { sent: 0, skipped: true };

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: "New canteen order",
      body: `${order.orderNumber} from ${order.customerName} • ₹${order.grandTotal}`,
    },
    data: {
      type: "new_order",
      orderId: String(order._id),
      orderNumber: String(order.orderNumber),
      canteenId: String(order.canteenId),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "new_orders",
        sound: "default",
        priority: "high",
        visibility: "public",
      },
    },
    apns: {
      payload: {
        aps: { sound: "default", badge: 1 },
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
    await Owner.findByIdAndUpdate(order.ownerId, {
      $pull: { fcmTokens: { $in: invalidTokens } },
    });
  }

  return {
    sent: response.successCount,
    failed: response.failureCount,
  };
};

module.exports = { sendNewOrderPush };
