const Canteen = require("../models/Canteen");
const MenuCategory = require("../models/MenuCategory");
const MenuItem = require("../models/MenuItem");
const Office = require("../models/Office");
const Order = require("../models/Order");
const crypto = require("crypto");
const { emitNewOrder } = require("../services/realtimeService");
const { sendNewOrderPush } = require("../services/pushNotificationService");

const indiaWeekday = (value = new Date()) => new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Kolkata",
  weekday: "long",
}).format(value);
const dayAvailabilityFilter = (value) => ({
  $or: [
    { availableDays: indiaWeekday(value) },
    { availableDays: { $exists: false } },
    { availableDays: { $size: 0 } },
  ],
});

const normalizeOfficeCode = (value) => value.trim().toUpperCase();
const normalizeCanteenCode = (value) => value.trim().toUpperCase();

/*
 * GET /api/public/offices/:officeCode
 * Public QR resolution. Only ordering-safe fields are returned.
 */
const resolveOfficeQr = async (req, res, next) => {
  try {
    const officeCode = normalizeOfficeCode(req.params.officeCode);

    const office = await Office.findOne({
      officeCode,
      status: "Active",
    })
      .select(
        "companyName building floor address city state pincode officeCode canteenIds",
      )
      .populate({
        path: "canteenIds",
        match: { status: "Active" },
        select:
          "name address city contactNumber openingTime closingTime serviceSlots status",
      })
      .lean();

    if (!office) {
      return res.status(404).json({
        success: false,
        message: "This office QR is invalid or currently inactive",
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        office: {
          id: office._id,
          companyName: office.companyName,
          building: office.building,
          floor: office.floor,
          address: office.address,
          city: office.city,
          state: office.state,
          pincode: office.pincode,
          officeCode: office.officeCode,
        },
        canteens: office.canteenIds,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/public/offices/:officeCode/canteens/:canteenId/menu
 * Returns only active categories and available items for an assigned canteen.
 */
const getPublicCanteenMenu = async (req, res, next) => {
  try {
    const officeCode = normalizeOfficeCode(req.params.officeCode);

    const office = await Office.findOne({
      officeCode,
      status: "Active",
      canteenIds: req.params.canteenId,
    })
      .select("_id companyName officeCode")
      .lean();

    if (!office) {
      return res.status(404).json({
        success: false,
        message: "This canteen is not available for the scanned office",
      });
    }

    const canteen = await Canteen.findOne({
      _id: req.params.canteenId,
      status: "Active",
    })
      .select(
        "name address city contactNumber openingTime closingTime serviceSlots status",
      )
      .lean();

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "This canteen is currently unavailable",
      });
    }

    const categories = await MenuCategory.find({
      canteenId: canteen._id,
      status: "Active",
    })
      .select("name displayOrder status")
      .sort({ displayOrder: 1, createdAt: 1 })
      .lean();

    const categoryIds = categories.map((category) => category._id);

    const items = await MenuItem.find({
      canteenId: canteen._id,
      categoryId: { $in: categoryIds },
      isAvailable: true,
      ...dayAvailabilityFilter(),
    })
      .select(
        "categoryId name description price foodType preparationTime imageUrl isAvailable availableDays",
      )
      .sort({ categoryId: 1, name: 1 })
      .lean();

    return res.status(200).json({
      success: true,
      data: {
        office: {
          id: office._id,
          companyName: office.companyName,
          officeCode: office.officeCode,
        },
        canteen,
        categories,
        items,
      },
    });
  } catch (error) {
    next(error);
  }
};

const createOrderNumber = () => {
  const time = Date.now().toString(36).toUpperCase();
  const random = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `ORD-${time}-${random}`;
};

const createTrackingToken = () => crypto.randomBytes(32).toString("hex");
const hashTrackingToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");

const serviceTimeToMinutes = (value) => {
  const match = String(value || "").trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
  if (!match) return null;
  let hour = Number(match[1]) % 12;
  if (match[3].toUpperCase() === "PM") hour += 12;
  return hour * 60 + Number(match[2]);
};

const indiaTimeParts = (date) => {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Kolkata",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return Number(values.hour) * 60 + Number(values.minute);
};

const resolveSchedule = (body, canteen) => {
  if (body.fulfillmentType !== "scheduled") {
    return { fulfillmentType: "asap", scheduledFor: null, scheduledSlot: "" };
  }
  const scheduledFor = new Date(body.scheduledFor);
  const now = Date.now();
  if (!Number.isFinite(scheduledFor.getTime()) || scheduledFor.getTime() < now + 15 * 60 * 1000) {
    const error = new Error("Scheduled time must be at least 15 minutes from now");
    error.statusCode = 400;
    throw error;
  }
  if (scheduledFor.getTime() > now + 7 * 24 * 60 * 60 * 1000) {
    const error = new Error("Orders can only be scheduled up to 7 days ahead");
    error.statusCode = 400;
    throw error;
  }
  const slots = canteen.serviceSlots?.length ? canteen.serviceSlots : [{
    label: "Service", openingTime: canteen.openingTime, closingTime: canteen.closingTime,
  }];
  const slot = slots.find(
    (item) => item.label.toLowerCase() === String(body.scheduledSlot || "").trim().toLowerCase(),
  );
  if (!slot) {
    const error = new Error("Select a valid canteen service slot");
    error.statusCode = 400;
    throw error;
  }
  const openingMinutes = serviceTimeToMinutes(slot.openingTime);
  const closingMinutes = serviceTimeToMinutes(slot.closingTime);
  const scheduledMinutes = indiaTimeParts(scheduledFor);
  const isInsideSlot = openingMinutes != null && closingMinutes != null && (
    openingMinutes <= closingMinutes
      ? scheduledMinutes >= openingMinutes && scheduledMinutes <= closingMinutes
      : scheduledMinutes >= openingMinutes || scheduledMinutes <= closingMinutes
  );
  if (!isInsideSlot) {
    const error = new Error(
      `Scheduled time must be between ${slot.openingTime} and ${slot.closingTime}`,
    );
    error.statusCode = 400;
    throw error;
  }
  return { fulfillmentType: "scheduled", scheduledFor, scheduledSlot: slot.label };
};

/*
 * POST /api/public/orders
 * Creates an employee order without authentication. Prices and availability
 * are always loaded from MongoDB; client-provided totals are ignored.
 */
const createPublicOrder = async (req, res, next) => {
  try {
    const officeCode = normalizeOfficeCode(req.body.officeCode);
    const { canteenId, customerName, mobile, customerNote = "", items } =
      req.body;
    const orderCustomerName = req.customer?.name || customerName;
    const orderMobile = req.customer?.mobile || mobile;

    const office = await Office.findOne({
      officeCode,
      status: "Active",
      canteenIds: canteenId,
    })
      .select(
        "ownerId companyName officeCode building floor address city canteenIds",
      )
      .lean();

    if (!office) {
      return res.status(404).json({
        success: false,
        message: "This canteen is not available for the scanned office",
      });
    }

    const canteen = await Canteen.findOne({
      _id: canteenId,
      ownerId: office.ownerId,
      status: "Active",
    })
      .select("name openingTime closingTime serviceSlots")
      .lean();

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "This canteen is currently unavailable",
      });
    }

    const itemIds = items.map((item) => item.menuItemId);
    const uniqueItemIds = [...new Set(itemIds.map(String))];

    if (uniqueItemIds.length !== itemIds.length) {
      return res.status(400).json({
        success: false,
        message: "Duplicate menu items are not allowed",
      });
    }

    const menuItems = await MenuItem.find({
      _id: { $in: uniqueItemIds },
      ownerId: office.ownerId,
      canteenId,
      isAvailable: true,
      ...dayAvailabilityFilter(req.body.fulfillmentType === "scheduled" ? new Date(req.body.scheduledFor) : undefined),
    })
      .select("name price preparationTime categoryId")
      .populate({ path: "categoryId", match: { status: "Active" }, select: "_id" })
      .lean();

    const availableItems = menuItems.filter((item) => item.categoryId);
    if (availableItems.length !== uniqueItemIds.length) {
      return res.status(409).json({
        success: false,
        message:
          "One or more cart items are no longer available. Refresh the menu and try again.",
      });
    }

    const menuItemById = new Map(
      availableItems.map((item) => [String(item._id), item]),
    );
    const orderItems = items.map((requestedItem) => {
      const menuItem = menuItemById.get(String(requestedItem.menuItemId));
      const quantity = Number(requestedItem.quantity);
      const unitPrice = Number(menuItem.price);
      return {
        menuItemId: menuItem._id,
        name: menuItem.name,
        unitPrice,
        quantity,
        lineTotal: unitPrice * quantity,
      };
    });

    const subtotal = orderItems.reduce(
      (total, item) => total + item.lineTotal,
      0,
    );
    const itemCount = orderItems.reduce(
      (total, item) => total + item.quantity,
      0,
    );
    const estimatedPreparationTime = availableItems.reduce(
      (longest, item) => Math.max(longest, Number(item.preparationTime || 0)),
      0,
    );

    const trackingToken = createTrackingToken();
    const schedule = resolveSchedule(req.body, canteen);
    const order = await Order.create({
      orderNumber: createOrderNumber(),
      trackingTokenHash: hashTrackingToken(trackingToken),
      trackingTokenIssuedAt: new Date(),
      ownerId: office.ownerId,
      customerId: req.customer?._id || null,
      officeId: office._id,
      canteenId: canteen._id,
      officeSnapshot: {
        companyName: office.companyName,
        officeCode: office.officeCode,
        building: office.building,
        floor: office.floor,
        address: office.address,
        city: office.city,
      },
      canteenSnapshot: { name: canteen.name },
      customerName: orderCustomerName.trim(),
      mobile: orderMobile.trim(),
      customerNote: customerNote.trim(),
      items: orderItems,
      itemCount,
      subtotal,
      grandTotal: subtotal,
      estimatedPreparationTime,
      ...schedule,
    });

    emitNewOrder(order);
    sendNewOrderPush(order).catch((error) => {
      console.error(`Unable to send new-order push notification: ${error.message}`);
    });

    return res.status(201).json({
      success: true,
      message: "Order placed successfully",
      data: {
        order: {
          id: order._id,
          orderNumber: order.orderNumber,
          customerName: order.customerName,
          itemCount: order.itemCount,
          grandTotal: order.grandTotal,
          estimatedPreparationTime: order.estimatedPreparationTime,
          orderStatus: order.orderStatus,
          paymentStatus: order.paymentStatus,
          canteenName: order.canteenSnapshot.name,
          createdAt: order.createdAt,
          fulfillmentType: order.fulfillmentType,
          scheduledFor: order.scheduledFor,
          scheduledSlot: order.scheduledSlot,
          trackingToken,
          trackingPath: `/track/${order.orderNumber}?token=${trackingToken}`,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/* GET /api/public/canteens/:publicCode */
const resolveCanteenMasterQr = async (req, res, next) => {
  try {
    const canteen = await Canteen.findOne({
      publicCode: normalizeCanteenCode(req.params.publicCode),
      status: "Active",
      masterQrEnabled: true,
    })
      .select("name address city contactNumber openingTime closingTime serviceSlots publicCode")
      .lean();

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "This canteen master QR is invalid or currently paused",
      });
    }

    return res.status(200).json({ success: true, data: { canteen } });
  } catch (error) {
    next(error);
  }
};

/* GET /api/public/canteens/:publicCode/menu */
const getMasterCanteenMenu = async (req, res, next) => {
  try {
    const canteen = await Canteen.findOne({
      publicCode: normalizeCanteenCode(req.params.publicCode),
      status: "Active",
      masterQrEnabled: true,
    })
      .select("name address city contactNumber openingTime closingTime serviceSlots publicCode")
      .lean();

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "This canteen is currently unavailable",
      });
    }

    const categories = await MenuCategory.find({
      canteenId: canteen._id,
      status: "Active",
    }).select("name displayOrder status").sort({ displayOrder: 1, createdAt: 1 }).lean();
    const categoryIds = categories.map((category) => category._id);
    const items = await MenuItem.find({
      canteenId: canteen._id,
      categoryId: { $in: categoryIds },
      isAvailable: true,
      ...dayAvailabilityFilter(),
    })
      .select("categoryId name description price foodType preparationTime imageUrl isAvailable availableDays")
      .sort({ categoryId: 1, name: 1 })
      .lean();

    return res.status(200).json({
      success: true,
      data: { orderSource: "canteen_master_qr", canteen, categories, items },
    });
  } catch (error) {
    next(error);
  }
};

/* POST /api/public/canteens/:publicCode/orders */
const createMasterQrOrder = async (req, res, next) => {
  try {
    const canteen = await Canteen.findOne({
      publicCode: normalizeCanteenCode(req.params.publicCode),
      status: "Active",
      masterQrEnabled: true,
    }).select("ownerId name publicCode openingTime closingTime serviceSlots").lean();

    if (!canteen) {
      return res.status(404).json({
        success: false,
        message: "This canteen is currently unavailable",
      });
    }

    const { customerName, mobile, customerNote = "", items, deliveryAddress } = req.body;
    const orderCustomerName = req.customer?.name || customerName;
    const orderMobile = req.customer?.mobile || mobile;
    const itemIds = items.map((item) => item.menuItemId);
    const uniqueItemIds = [...new Set(itemIds.map(String))];
    if (uniqueItemIds.length !== itemIds.length) {
      return res.status(400).json({ success: false, message: "Duplicate menu items are not allowed" });
    }

    const menuItems = await MenuItem.find({
      _id: { $in: uniqueItemIds },
      ownerId: canteen.ownerId,
      canteenId: canteen._id,
      isAvailable: true,
      ...dayAvailabilityFilter(req.body.fulfillmentType === "scheduled" ? new Date(req.body.scheduledFor) : undefined),
    })
      .select("name price preparationTime categoryId")
      .populate({ path: "categoryId", match: { status: "Active" }, select: "_id" })
      .lean();
    const availableItems = menuItems.filter((item) => item.categoryId);
    if (availableItems.length !== uniqueItemIds.length) {
      return res.status(409).json({
        success: false,
        message: "One or more cart items are no longer available. Refresh the menu and try again.",
      });
    }

    const menuItemById = new Map(availableItems.map((item) => [String(item._id), item]));
    const orderItems = items.map((requestedItem) => {
      const menuItem = menuItemById.get(String(requestedItem.menuItemId));
      const quantity = Number(requestedItem.quantity);
      const unitPrice = Number(menuItem.price);
      return {
        menuItemId: menuItem._id,
        name: menuItem.name,
        unitPrice,
        quantity,
        lineTotal: unitPrice * quantity,
      };
    });
    const subtotal = orderItems.reduce((sum, item) => sum + item.lineTotal, 0);
    const itemCount = orderItems.reduce((sum, item) => sum + item.quantity, 0);
    const estimatedPreparationTime = availableItems.reduce(
      (longest, item) => Math.max(longest, Number(item.preparationTime || 0)),
      0,
    );
    const trackingToken = createTrackingToken();
    const schedule = resolveSchedule(req.body, canteen);
    const cleanAddress = {
      buildingName: deliveryAddress.buildingName.trim(),
      floorOrRoom: deliveryAddress.floorOrRoom.trim(),
      streetArea: deliveryAddress.streetArea.trim(),
      landmark: (deliveryAddress.landmark || "").trim(),
      city: deliveryAddress.city.trim(),
      pincode: deliveryAddress.pincode.trim(),
    };
    const order = await Order.create({
      orderNumber: createOrderNumber(),
      trackingTokenHash: hashTrackingToken(trackingToken),
      trackingTokenIssuedAt: new Date(),
      ownerId: canteen.ownerId,
      customerId: req.customer?._id || null,
      orderSource: "canteen_master_qr",
      canteenId: canteen._id,
      canteenSnapshot: { name: canteen.name },
      deliveryAddress: cleanAddress,
      customerName: orderCustomerName.trim(),
      mobile: orderMobile.trim(),
      customerNote: customerNote.trim(),
      items: orderItems,
      itemCount,
      subtotal,
      grandTotal: subtotal,
      estimatedPreparationTime,
      ...schedule,
    });

    emitNewOrder(order);
    sendNewOrderPush(order).catch((error) => {
      console.error(`Unable to send new-order push notification: ${error.message}`);
    });

    return res.status(201).json({
      success: true,
      message: "Order placed successfully",
      data: {
        order: {
          id: order._id,
          orderNumber: order.orderNumber,
          customerName: order.customerName,
          itemCount: order.itemCount,
          grandTotal: order.grandTotal,
          estimatedPreparationTime: order.estimatedPreparationTime,
          orderStatus: order.orderStatus,
          paymentStatus: order.paymentStatus,
          canteenName: order.canteenSnapshot.name,
          createdAt: order.createdAt,
          fulfillmentType: order.fulfillmentType,
          scheduledFor: order.scheduledFor,
          scheduledSlot: order.scheduledSlot,
          trackingToken,
          trackingPath: `/track/${order.orderNumber}?token=${trackingToken}`,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/public/orders/:orderNumber/track?token=...
 * Public status lookup protected by a high-entropy token issued at checkout.
 */
const trackPublicOrder = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      orderNumber: req.params.orderNumber.toUpperCase(),
      trackingTokenHash: hashTrackingToken(req.query.token),
    })
      .select(
        "orderNumber orderSource officeSnapshot deliveryAddress canteenSnapshot customerName items itemCount grandTotal estimatedPreparationTime orderStatus paymentStatus fulfillmentType scheduledFor scheduledSlot acceptedAt deliveredAt rejectedAt cancelledAt createdAt updatedAt",
      )
      .lean();

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order tracking details were not found",
      });
    }

    return res.status(200).json({
      success: true,
      data: { order },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  resolveOfficeQr,
  getPublicCanteenMenu,
  createPublicOrder,
  trackPublicOrder,
  resolveCanteenMasterQr,
  getMasterCanteenMenu,
  createMasterQrOrder,
};
