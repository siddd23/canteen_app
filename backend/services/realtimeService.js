const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const { Server } = require("socket.io");

const Owner = require("../models/Owner");
const Order = require("../models/Order");
const { getAllowedOrigins } = require("../config/environment");

let io;

const ownerRoom = (ownerId) => `owner:${ownerId}`;
const orderRoom = (orderId) => `order:${orderId}`;
const hashTrackingToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");

const authenticateOwner = async (token) => {
  const decoded = jwt.verify(token, process.env.JWT_SECRET, {
    issuer: "canteen-app",
    audience: "canteen-app-users",
  });
  if (decoded.role !== "canteen_owner") throw new Error("Owner access required");

  const owner = await Owner.findById(decoded.id).select("approvalStatus +passwordChangedAt");
  if (!owner || owner.approvalStatus !== "Approved") throw new Error("Owner account is unavailable");
  if (owner.passwordChangedAt && decoded.iat * 1000 < owner.passwordChangedAt.getTime()) {
    throw new Error("Session expired");
  }
  return owner;
};

const initializeRealtime = (httpServer) => {
  const allowedOrigins = getAllowedOrigins();
  io = new Server(httpServer, {
    path: "/socket.io",
    cors: {
      origin(origin, callback) {
        if (!origin || process.env.NODE_ENV !== "production" || allowedOrigins.includes(origin)) {
          return callback(null, true);
        }
        return callback(new Error("Origin is not allowed"));
      },
      credentials: true,
    },
    transports: ["websocket", "polling"],
    pingTimeout: 20000,
    pingInterval: 25000,
  });

  io.use(async (socket, next) => {
    try {
      const auth = socket.handshake.auth || {};
      if (auth.token) {
        const owner = await authenticateOwner(String(auth.token));
        socket.data.ownerId = String(owner._id);
        socket.data.kind = "owner";
        return next();
      }

      if (auth.orderNumber && auth.trackingToken) {
        const order = await Order.findOne({
          orderNumber: String(auth.orderNumber).trim().toUpperCase(),
          trackingTokenHash: hashTrackingToken(String(auth.trackingToken)),
        }).select("_id");
        if (!order) throw new Error("Invalid tracking credentials");
        socket.data.orderId = String(order._id);
        socket.data.kind = "employee";
        return next();
      }

      throw new Error("Authentication is required");
    } catch (_) {
      const error = new Error("Realtime authentication failed");
      error.data = { code: "UNAUTHORIZED" };
      next(error);
    }
  });

  io.on("connection", (socket) => {
    if (socket.data.kind === "owner") socket.join(ownerRoom(socket.data.ownerId));
    if (socket.data.kind === "employee") socket.join(orderRoom(socket.data.orderId));
    socket.emit("realtime:ready", { connectedAt: new Date().toISOString() });
  });

  return io;
};

const newOrderPayload = (order) => ({
  id: String(order._id),
  orderNumber: order.orderNumber,
  canteenId: String(order.canteenId),
  canteenName: order.canteenSnapshot?.name || "Canteen",
  customerName: order.customerName,
  itemCount: order.itemCount,
  grandTotal: order.grandTotal,
  orderStatus: order.orderStatus,
  fulfillmentType: order.fulfillmentType,
  scheduledFor: order.scheduledFor,
  scheduledSlot: order.scheduledSlot,
  createdAt: order.createdAt,
});

const emitNewOrder = (order) => {
  if (!io) return;
  io.to(ownerRoom(order.ownerId)).emit("order:new", newOrderPayload(order));
};

const emitOrderUpdated = (order) => {
  if (!io) return;
  const payload = {
    id: String(order._id),
    orderNumber: order.orderNumber,
    orderStatus: order.orderStatus,
    paymentStatus: order.paymentStatus,
    updatedAt: order.updatedAt,
  };
  io.to(ownerRoom(order.ownerId)).emit("order:updated", payload);
  io.to(orderRoom(order._id)).emit("order:updated", payload);
};

module.exports = { initializeRealtime, emitNewOrder, emitOrderUpdated };
