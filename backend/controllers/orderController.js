const mongoose = require("mongoose");
const Order = require("../models/Order");
const MenuItem = require("../models/MenuItem");
const { emitOrderUpdated } = require("../services/realtimeService");

const employeeKey = (name, mobile) =>
  `${String(name || "").trim().toLowerCase().replace(/\s+/g, " ")}:${String(mobile || "").trim()}`;

const escapeRegex = (value) =>
  String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const getMyOrders = async (req, res, next) => {
  try {
    const filter = { ownerId: req.user.id };
    if (req.query.canteenId) filter.canteenId = req.query.canteenId;
    if (req.query.status) filter.orderStatus = req.query.status;
    if (req.query.paymentStatus) filter.paymentStatus = req.query.paymentStatus;

    const orders = await Order.find(filter).sort({ createdAt: -1 }).lean();
    return res.status(200).json({
      success: true,
      count: orders.length,
      data: { orders },
    });
  } catch (error) {
    next(error);
  }
};

const getOrderHistory = async (req, res, next) => {
  try {
    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 20);
    const filter = { ownerId: req.user.id };

    if (req.query.officeId) filter.officeId = req.query.officeId;
    if (req.query.canteenId) filter.canteenId = req.query.canteenId;
    if (req.query.status) filter.orderStatus = req.query.status;
    if (req.query.paymentStatus) {
      filter.paymentStatus = req.query.paymentStatus;
    }

    if (req.query.dateFrom || req.query.dateTo) {
      filter.createdAt = {};
      if (req.query.dateFrom) {
        filter.createdAt.$gte = new Date(`${req.query.dateFrom}T00:00:00+05:30`);
      }
      if (req.query.dateTo) {
        filter.createdAt.$lte = new Date(`${req.query.dateTo}T23:59:59.999+05:30`);
      }
      if (
        filter.createdAt.$gte &&
        filter.createdAt.$lte &&
        filter.createdAt.$gte > filter.createdAt.$lte
      ) {
        return res.status(400).json({
          success: false,
          message: "From date cannot be later than to date",
        });
      }
    }

    const search = req.query.search?.trim();
    if (search) {
      const pattern = new RegExp(escapeRegex(search), "i");
      filter.$or = [
        { orderNumber: pattern },
        { customerName: pattern },
        { mobile: pattern },
        { "officeSnapshot.companyName": pattern },
        { "officeSnapshot.officeCode": pattern },
        { "canteenSnapshot.name": pattern },
      ];
    }

    const [orders, totalOrders] = await Promise.all([
      Order.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      Order.countDocuments(filter),
    ]);
    const totalPages = Math.max(1, Math.ceil(totalOrders / limit));

    return res.status(200).json({
      success: true,
      data: {
        orders,
        pagination: {
          page,
          limit,
          totalOrders,
          totalPages,
          hasPreviousPage: page > 1,
          hasNextPage: page < totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const deleteOrderHistory = async (req, res, next) => {
  try {
    const mode = req.body.mode || "selected";
    const terminalStatuses = ["Delivered", "Rejected", "Cancelled"];
    const filter = {
      ownerId: req.user.id,
      orderStatus: { $in: terminalStatuses },
    };

    if (mode === "selected") {
      const ids = [...new Set(req.body.orderIds || [])];
      if (ids.length === 0) {
        return res.status(400).json({
          success: false,
          message: "Select at least one history record",
        });
      }
      filter._id = { $in: ids };
      filter.$or = [
        { paymentStatus: "Paid" },
        { orderStatus: { $in: ["Rejected", "Cancelled"] } },
      ];
    } else {
      // A filtered cleanup never removes unpaid or Pay Later records.
      filter.paymentStatus = "Paid";
      if (req.body.canteenId) filter.canteenId = req.body.canteenId;
      if (req.body.officeId) filter.officeId = req.body.officeId;
      if (req.body.dateFrom || req.body.dateTo) {
        filter.createdAt = {};
        if (req.body.dateFrom) {
          filter.createdAt.$gte = new Date(`${req.body.dateFrom}T00:00:00+05:30`);
        }
        if (req.body.dateTo) {
          filter.createdAt.$lte = new Date(`${req.body.dateTo}T23:59:59.999+05:30`);
        }
        if (
          filter.createdAt.$gte &&
          filter.createdAt.$lte &&
          filter.createdAt.$gte > filter.createdAt.$lte
        ) {
          return res.status(400).json({
            success: false,
            message: "From date cannot be later than to date",
          });
        }
      }
    }

    const result = await Order.deleteMany(filter);
    return res.status(200).json({
      success: true,
      message: `${result.deletedCount} history record${result.deletedCount === 1 ? "" : "s"} deleted`,
      data: { deletedCount: result.deletedCount },
    });
  } catch (error) {
    next(error);
  }
};

const getOfficeStatement = async (req, res, next) => {
  try {
    const filter = { ownerId: req.user.id, officeId: req.query.officeId };
    if (req.query.dateFrom || req.query.dateTo) {
      filter.createdAt = {};
      if (req.query.dateFrom) {
        filter.createdAt.$gte = new Date(`${req.query.dateFrom}T00:00:00+05:30`);
      }
      if (req.query.dateTo) {
        filter.createdAt.$lte = new Date(`${req.query.dateTo}T23:59:59.999+05:30`);
      }
      if (
        filter.createdAt.$gte &&
        filter.createdAt.$lte &&
        filter.createdAt.$gte > filter.createdAt.$lte
      ) {
        return res.status(400).json({
          success: false,
          message: "From date cannot be later than to date",
        });
      }
    }
    const orders = await Order.find(filter).sort({ createdAt: -1 }).lean();
    return res.status(200).json({
      success: true,
      data: {
        orders,
        summary: {
          orderCount: orders.length,
          totalAmount: orders
            .filter((order) => order.orderStatus === "Delivered")
            .reduce((sum, order) => sum + Number(order.grandTotal || 0), 0),
          paidAmount: orders
            .filter((order) => order.paymentStatus === "Paid")
            .reduce((sum, order) => sum + Number(order.grandTotal || 0), 0),
          outstandingAmount: orders
            .filter((order) => order.paymentStatus === "PayLater")
            .reduce((sum, order) => sum + Number(order.grandTotal || 0), 0),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const getCustomerStatement = async (req, res, next) => {
  try {
    const requestedKey = employeeKey(req.query.customerName, req.query.mobile);
    const filter = {
      ownerId: req.user.id,
      $or: [
        { employeeKey: requestedKey },
        {
          customerName: new RegExp(`^${escapeRegex(req.query.customerName.trim())}$`, "i"),
          mobile: req.query.mobile.trim(),
        },
      ],
    };
    if (req.query.canteenId) filter.canteenId = req.query.canteenId;
    if (req.query.dateFrom || req.query.dateTo) {
      filter.createdAt = {};
      if (req.query.dateFrom) filter.createdAt.$gte = new Date(`${req.query.dateFrom}T00:00:00+05:30`);
      if (req.query.dateTo) filter.createdAt.$lte = new Date(`${req.query.dateTo}T23:59:59.999+05:30`);
    }
    const orders = await Order.find(filter).sort({ createdAt: -1 }).lean();
    return res.status(200).json({
      success: true,
      data: {
        orders,
        summary: {
          orderCount: orders.length,
          totalAmount: orders.reduce((sum, order) => sum + Number(order.grandTotal || 0), 0),
          paidAmount: orders.filter((order) => order.paymentStatus === "Paid")
            .reduce((sum, order) => sum + Number(order.grandTotal || 0), 0),
          outstandingAmount: orders.filter((order) => order.paymentStatus === "PayLater")
            .reduce((sum, order) => sum + Number(order.grandTotal || 0), 0),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const getSalesReport = async (req, res, next) => {
  try {
    const ownerId = new mongoose.Types.ObjectId(req.user.id);
    const endDate = req.query.dateTo || new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Kolkata",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());
    const defaultStart = new Date(`${endDate}T00:00:00+05:30`);
    defaultStart.setUTCDate(defaultStart.getUTCDate() - 29);
    const startDate = req.query.dateFrom || new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Kolkata",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(defaultStart);
    const periodStart = new Date(`${startDate}T00:00:00+05:30`);
    const periodEnd = new Date(`${endDate}T23:59:59.999+05:30`);

    if (periodStart > periodEnd) {
      return res.status(400).json({
        success: false,
        message: "From date cannot be later than to date",
      });
    }

    const baseMatch = { ownerId };
    if (req.query.canteenId) {
      baseMatch.canteenId = new mongoose.Types.ObjectId(req.query.canteenId);
    }
    const deliveredInPeriod = {
      orderStatus: "Delivered",
      deliveredAt: { $gte: periodStart, $lte: periodEnd },
    };

    const [result] = await Order.aggregate([
      { $match: baseMatch },
      {
        $facet: {
          placed: [
            { $match: { createdAt: { $gte: periodStart, $lte: periodEnd } } },
            { $count: "count" },
          ],
          deliveredSummary: [
            { $match: deliveredInPeriod },
            {
              $group: {
                _id: null,
                orderCount: { $sum: 1 },
                grossSales: { $sum: "$grandTotal" },
              },
            },
          ],
          collections: [
            {
              $match: {
                paymentStatus: "Paid",
                paidAt: { $gte: periodStart, $lte: periodEnd },
              },
            },
            {
              $group: {
                _id: null,
                orderCount: { $sum: 1 },
                amount: { $sum: "$grandTotal" },
              },
            },
          ],
          payLaterCreated: [
            { $match: { ...deliveredInPeriod, paymentStatus: "PayLater" } },
            { $group: { _id: null, orderCount: { $sum: 1 }, amount: { $sum: "$grandTotal" } } },
          ],
          currentOutstanding: [
            { $match: { orderStatus: "Delivered", paymentStatus: "PayLater" } },
            { $group: { _id: null, orderCount: { $sum: 1 }, amount: { $sum: "$grandTotal" } } },
          ],
          dailySales: [
            { $match: deliveredInPeriod },
            {
              $group: {
                _id: {
                  $dateToString: {
                    date: "$deliveredAt",
                    format: "%Y-%m-%d",
                    timezone: "Asia/Kolkata",
                  },
                },
                orderCount: { $sum: 1 },
                sales: { $sum: "$grandTotal" },
              },
            },
            { $sort: { _id: 1 } },
          ],
          topItems: [
            { $match: deliveredInPeriod },
            { $unwind: "$items" },
            {
              $group: {
                _id: "$items.name",
                quantity: { $sum: "$items.quantity" },
                revenue: { $sum: "$items.lineTotal" },
              },
            },
            { $sort: { quantity: -1, revenue: -1 } },
            { $limit: 10 },
          ],
          officeSales: [
            { $match: deliveredInPeriod },
            {
              $group: {
                _id: {
                  officeId: "$officeId",
                  companyName: {
                    $cond: [
                      { $eq: ["$orderSource", "canteen_master_qr"] },
                      "Direct Master QR",
                      "$officeSnapshot.companyName",
                    ],
                  },
                },
                orderCount: { $sum: 1 },
                sales: { $sum: "$grandTotal" },
              },
            },
            { $sort: { sales: -1 } },
            { $limit: 10 },
          ],
          paymentBreakdown: [
            { $match: deliveredInPeriod },
            {
              $group: {
                _id: "$paymentStatus",
                orderCount: { $sum: 1 },
                amount: { $sum: "$grandTotal" },
              },
            },
          ],
        },
      },
    ]);

    const value = (items, field) =>
      Array.isArray(items) && items.length > 0 ? Number(items[0][field] || 0) : 0;
    const deliveredOrders = value(result?.deliveredSummary, "orderCount");
    const grossSales = value(result?.deliveredSummary, "grossSales");

    return res.status(200).json({
      success: true,
      data: {
        period: { dateFrom: startDate, dateTo: endDate },
        summary: {
          placedOrders: value(result?.placed, "count"),
          deliveredOrders,
          grossSales,
          averageOrderValue: deliveredOrders > 0 ? grossSales / deliveredOrders : 0,
          collectedAmount: value(result?.collections, "amount"),
          collectedOrders: value(result?.collections, "orderCount"),
          payLaterCreated: value(result?.payLaterCreated, "amount"),
          payLaterCreatedOrders: value(result?.payLaterCreated, "orderCount"),
          currentOutstanding: value(result?.currentOutstanding, "amount"),
          currentOutstandingOrders: value(result?.currentOutstanding, "orderCount"),
        },
        dailySales: (result?.dailySales || []).map((item) => ({
          date: item._id,
          orderCount: item.orderCount,
          sales: item.sales,
        })),
        topItems: (result?.topItems || []).map((item) => ({
          name: item._id,
          quantity: item.quantity,
          revenue: item.revenue,
        })),
        officeSales: (result?.officeSales || []).map((item) => ({
          officeId: item._id.officeId,
          companyName: item._id.companyName,
          orderCount: item.orderCount,
          sales: item.sales,
        })),
        paymentBreakdown: (result?.paymentBreakdown || []).map((item) => ({
          paymentStatus: item._id,
          orderCount: item.orderCount,
          amount: item.amount,
        })),
      },
    });
  } catch (error) {
    next(error);
  }
};

const getDashboardSummary = async (req, res, next) => {
  try {
    const { canteenId } = req.query;
    const ownerId = req.user.id;

    // Canteen operations currently use Indian business dates. Explicit UTC
    // boundaries keep the numbers correct even when the server runs elsewhere.
    const indiaDate = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Kolkata",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());
    const startOfDay = new Date(`${indiaDate}T00:00:00+05:30`);
    const endOfDay = new Date(`${indiaDate}T23:59:59.999+05:30`);

    const baseFilter = {
      ownerId: new mongoose.Types.ObjectId(ownerId),
      canteenId: new mongoose.Types.ObjectId(canteenId),
    };
    const [orderSummary, availableMenuItems] = await Promise.all([
      Order.aggregate([
        { $match: baseFilter },
        {
          $facet: {
            todayOrders: [
              { $match: { createdAt: { $gte: startOfDay, $lte: endOfDay } } },
              { $count: "count" },
            ],
            pendingOrders: [
              { $match: { orderStatus: "Pending" } },
              { $count: "count" },
            ],
            activeOrders: [
              { $match: { orderStatus: { $in: ["Pending", "Accepted"] } } },
              { $count: "count" },
            ],
            todaySales: [
              {
                $match: {
                  orderStatus: "Delivered",
                  deliveredAt: { $gte: startOfDay, $lte: endOfDay },
                },
              },
              { $group: { _id: null, amount: { $sum: "$grandTotal" } } },
            ],
            payLater: [
              {
                $match: {
                  orderStatus: "Delivered",
                  paymentStatus: "PayLater",
                },
              },
              {
                $group: {
                  _id: null,
                  amount: { $sum: "$grandTotal" },
                  orderCount: { $sum: 1 },
                },
              },
            ],
          },
        },
      ]),
      MenuItem.countDocuments({ ...baseFilter, isAvailable: true }),
    ]);

    const summary = orderSummary[0] || {};
    const firstValue = (items, field = "count") =>
      Array.isArray(items) && items.length > 0 ? Number(items[0][field] || 0) : 0;

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          todayOrders: firstValue(summary.todayOrders),
          pendingOrders: firstValue(summary.pendingOrders),
          activeOrders: firstValue(summary.activeOrders),
          todaySales: firstValue(summary.todaySales, "amount"),
          availableMenuItems,
          payLaterOutstanding: firstValue(summary.payLater, "amount"),
          payLaterOrderCount: firstValue(summary.payLater, "orderCount"),
          businessDate: indiaDate,
          updatedAt: new Date(),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const getOrderNotifications = async (req, res, next) => {
  try {
    // Capture the upper boundary before querying so an order created during
    // this request is safely returned by the following poll.
    const checkedAt = new Date();
    if (!req.query.after) {
      return res.status(200).json({
        success: true,
        data: { notifications: [], checkedAt },
      });
    }

    const after = new Date(req.query.after);
    const orders = await Order.find({
      ownerId: req.user.id,
      createdAt: { $gt: after, $lte: checkedAt },
    })
      .select(
        "orderNumber canteenId canteenSnapshot customerName itemCount grandTotal orderStatus createdAt",
      )
      .sort({ createdAt: 1 })
      .lean();

    const notifications = orders.map((order) => ({
      id: order._id,
      orderNumber: order.orderNumber,
      canteenId: order.canteenId,
      canteenName: order.canteenSnapshot?.name || "Canteen",
      customerName: order.customerName,
      itemCount: order.itemCount,
      grandTotal: order.grandTotal,
      orderStatus: order.orderStatus,
      createdAt: order.createdAt,
    }));

    return res.status(200).json({
      success: true,
      data: { notifications, checkedAt },
    });
  } catch (error) {
    next(error);
  }
};

const updateOrderStatus = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      _id: req.params.orderId,
      ownerId: req.user.id,
    });

    if (!order) {
      return res.status(404).json({ success: false, message: "Order not found" });
    }

    const transitions = {
      Pending: ["Accepted", "Rejected"],
      Accepted: ["Delivered"],
      Delivered: [],
      Rejected: [],
      Cancelled: [],
    };
    const nextStatus = req.body.status;
    if (!transitions[order.orderStatus].includes(nextStatus)) {
      return res.status(409).json({
        success: false,
        message: `Order cannot move from ${order.orderStatus} to ${nextStatus}`,
      });
    }

    order.orderStatus = nextStatus;
    const timestampField = {
      Accepted: "acceptedAt",
      Delivered: "deliveredAt",
      Rejected: "rejectedAt",
    }[nextStatus];
    if (timestampField) order[timestampField] = new Date();
    await order.save();
    emitOrderUpdated(order);

    return res.status(200).json({
      success: true,
      message: `Order marked as ${nextStatus.toLowerCase()}`,
      data: { order },
    });
  } catch (error) {
    next(error);
  }
};

const updatePaymentStatus = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      _id: req.params.orderId,
      ownerId: req.user.id,
    });

    if (!order) {
      return res.status(404).json({ success: false, message: "Order not found" });
    }
    if (order.orderStatus !== "Delivered") {
      return res.status(409).json({
        success: false,
        message: "Payment can be recorded only after delivery",
      });
    }

    const nextStatus = req.body.status;
    if (
      nextStatus === "PayLater" &&
      req.user.owner.preferences?.payLaterEnabled === false
    ) {
      return res.status(403).json({
        success: false,
        message: "Pay Later is disabled in account settings",
      });
    }
    if (order.paymentStatus === "Paid") {
      return res.status(409).json({
        success: false,
        message: "This order is already paid",
      });
    }
    if (order.paymentStatus === "PayLater" && nextStatus !== "Paid") {
      return res.status(409).json({
        success: false,
        message: "A Pay Later order can only be marked as paid",
      });
    }

    order.paymentStatus = nextStatus;
    order.paidAt = nextStatus === "Paid" ? new Date() : null;
    await order.save();
    emitOrderUpdated(order);

    return res.status(200).json({
      success: true,
      message: nextStatus === "Paid" ? "Payment received" : "Added to Pay Later",
      data: { order },
    });
  } catch (error) {
    next(error);
  }
};

const getPayLaterEmployees = async (req, res, next) => {
  try {
    const filter = {
      ownerId: req.user.id,
      orderStatus: "Delivered",
      paymentStatus: "PayLater",
    };
    if (req.query.canteenId) filter.canteenId = req.query.canteenId;

    const orders = await Order.find(filter).sort({ deliveredAt: -1, createdAt: -1 }).lean();
    const grouped = new Map();

    for (const order of orders) {
      const key = order.employeeKey || employeeKey(order.customerName, order.mobile);
      const existing = grouped.get(key) || {
        employeeKey: key,
        customerName: order.customerName,
        mobile: order.mobile,
        totalOutstanding: 0,
        orderCount: 0,
        itemCount: 0,
        latestOrderAt: order.deliveredAt || order.createdAt,
        orders: [],
      };
      existing.totalOutstanding += Number(order.grandTotal || 0);
      existing.orderCount += 1;
      existing.itemCount += Number(order.itemCount || 0);
      existing.orders.push(order);
      grouped.set(key, existing);
    }

    const employees = [...grouped.values()].sort(
      (a, b) => new Date(b.latestOrderAt) - new Date(a.latestOrderAt),
    );
    const totalOutstanding = employees.reduce(
      (sum, employee) => sum + employee.totalOutstanding,
      0,
    );

    return res.status(200).json({
      success: true,
      data: {
        employees,
        summary: {
          employeeCount: employees.length,
          orderCount: orders.length,
          totalOutstanding,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const settleEmployeePayLater = async (req, res, next) => {
  try {
    const { customerName, mobile } = req.body;
    const requestedKey = employeeKey(customerName, mobile);
    const filter = {
      ownerId: req.user.id,
      orderStatus: "Delivered",
      paymentStatus: "PayLater",
    };
    if (req.body.canteenId) filter.canteenId = req.body.canteenId;

    const candidates = await Order.find(filter).select("customerName mobile employeeKey");
    const ids = candidates
      .filter((order) => (order.employeeKey || employeeKey(order.customerName, order.mobile)) === requestedKey)
      .map((order) => order._id);

    if (ids.length === 0) {
      return res.status(404).json({ success: false, message: "No Pay Later bills found for this employee" });
    }

    const paidAt = new Date();
    await Order.updateMany(
      { _id: { $in: ids }, ownerId: req.user.id, paymentStatus: "PayLater" },
      { $set: { paymentStatus: "Paid", paidAt } },
    );

    return res.status(200).json({
      success: true,
      message: `${ids.length} bill${ids.length === 1 ? "" : "s"} marked as paid`,
      data: { settledOrderCount: ids.length, paidAt },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getSalesReport,
  getOrderHistory,
  deleteOrderHistory,
  getOfficeStatement,
  getCustomerStatement,
  getDashboardSummary,
  getOrderNotifications,
  getMyOrders,
  updateOrderStatus,
  updatePaymentStatus,
  getPayLaterEmployees,
  settleEmployeePayLater,
};
