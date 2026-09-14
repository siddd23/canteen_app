const Canteen = require("../models/Canteen");
const MenuCategory = require("../models/MenuCategory");
const MenuItem = require("../models/MenuItem");
const Office = require("../models/Office");
const Order = require("../models/Order");
const crypto = require("crypto");
const { emitNewOrder } = require("../services/realtimeService");
const { sendNewOrderPush } = require("../services/pushNotificationService");

const normalizeOfficeCode = (value) => value.trim().toUpperCase();

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
          "name address city contactNumber openingTime closingTime status",
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
        "name address city contactNumber openingTime closingTime status",
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
    })
      .select(
        "categoryId name description price foodType preparationTime imageUrl isAvailable",
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
      .select("name")
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
    const order = await Order.create({
      orderNumber: createOrderNumber(),
      trackingTokenHash: hashTrackingToken(trackingToken),
      trackingTokenIssuedAt: new Date(),
      ownerId: office.ownerId,
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
      customerName: customerName.trim(),
      mobile: mobile.trim(),
      customerNote: customerNote.trim(),
      items: orderItems,
      itemCount,
      subtotal,
      grandTotal: subtotal,
      estimatedPreparationTime,
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
        "orderNumber officeSnapshot canteenSnapshot customerName items itemCount grandTotal estimatedPreparationTime orderStatus paymentStatus acceptedAt deliveredAt rejectedAt cancelledAt createdAt updatedAt",
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
};
