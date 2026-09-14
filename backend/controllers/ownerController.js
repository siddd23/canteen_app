const Owner = require("../models/Owner");
const Canteen = require("../models/Canteen");
const Office = require("../models/Office");
const Order = require("../models/Order");

const startOfIndiaDay = () => {
  const now = new Date();
  const indiaOffsetMilliseconds = 5.5 * 60 * 60 * 1000;
  const indiaNow = new Date(now.getTime() + indiaOffsetMilliseconds);
  indiaNow.setUTCHours(0, 0, 0, 0);
  return new Date(indiaNow.getTime() - indiaOffsetMilliseconds);
};

/*
 * GET /api/admin/owners/overview
 * Platform-wide operational summary for the Super Admin dashboard.
 */
const getAdminOverview = async (req, res, next) => {
  try {
    const todayStart = startOfIndiaDay();

    const [
      ownerStatuses,
      totalCanteens,
      activeCanteens,
      totalOffices,
      activeOffices,
      totalOrders,
      todayOrders,
      pendingOrders,
      todaySalesResult,
      payLaterResult,
      recentOrders,
    ] = await Promise.all([
      Owner.aggregate([
        { $group: { _id: "$approvalStatus", count: { $sum: 1 } } },
      ]),
      Canteen.countDocuments(),
      Canteen.countDocuments({ status: "Active" }),
      Office.countDocuments(),
      Office.countDocuments({ status: "Active" }),
      Order.countDocuments(),
      Order.countDocuments({ createdAt: { $gte: todayStart } }),
      Order.countDocuments({ orderStatus: "Pending" }),
      Order.aggregate([
        {
          $match: {
            orderStatus: "Delivered",
            deliveredAt: { $gte: todayStart },
          },
        },
        { $group: { _id: null, amount: { $sum: "$grandTotal" } } },
      ]),
      Order.aggregate([
        { $match: { paymentStatus: "PayLater" } },
        {
          $group: {
            _id: null,
            amount: { $sum: "$grandTotal" },
            orderCount: { $sum: 1 },
          },
        },
      ]),
      Order.find()
        .sort({ createdAt: -1 })
        .limit(8)
        .select(
          "orderNumber customerName mobile grandTotal orderStatus paymentStatus canteenSnapshot officeSnapshot createdAt",
        )
        .lean(),
    ]);

    const ownerCount = ownerStatuses.reduce(
      (summary, item) => ({ ...summary, [item._id]: item.count }),
      {},
    );
    const payLater = payLaterResult[0] || {};

    return res.status(200).json({
      success: true,
      data: {
        overview: {
          owners: {
            total: ownerStatuses.reduce((sum, item) => sum + item.count, 0),
            pending: ownerCount.Pending || 0,
            approved: ownerCount.Approved || 0,
            rejected: ownerCount.Rejected || 0,
            blocked: ownerCount.Blocked || 0,
          },
          canteens: { total: totalCanteens, active: activeCanteens },
          offices: { total: totalOffices, active: activeOffices },
          orders: { total: totalOrders, today: todayOrders, pending: pendingOrders },
          todaySales: todaySalesResult[0]?.amount || 0,
          payLaterOutstanding: payLater.amount || 0,
          payLaterOrderCount: payLater.orderCount || 0,
          recentOrders,
          updatedAt: new Date().toISOString(),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/admin/owners/pending
 * Super Admin only
 */
const getPendingOwners = async (req, res, next) => {
  try {
    const owners = await Owner.find({
      approvalStatus: "Pending",
    })
      .sort({ createdAt: 1 })
      .select("-password");

    return res.status(200).json({
      success: true,
      count: owners.length,
      data: {
        owners,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/admin/owners
 * Super Admin only
 *
 * Optional:
 * /api/admin/owners?status=Approved
 */
const getOwners = async (req, res, next) => {
  try {
    const filter = {};
    const allowedStatuses = [
      "Pending",
      "Approved",
      "Rejected",
      "Blocked",
    ];

    if (req.query.status) {
      if (!allowedStatuses.includes(req.query.status)) {
        return res.status(400).json({
          success: false,
          message: "Invalid approval status",
        });
      }

      filter.approvalStatus = req.query.status;
    }

    const owners = await Owner.find(filter)
      .sort({ createdAt: -1 })
      .select("-password");

    return res.status(200).json({
      success: true,
      count: owners.length,
      data: {
        owners,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/admin/owners/:ownerId
 * Super Admin only
 */
const getOwnerById = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.params.ownerId)
      .select("-password");

    if (!owner) {
      return res.status(404).json({
        success: false,
        message: "Owner registration not found",
      });
    }

    const canteens = await Canteen.find({
      ownerId: owner._id,
    }).sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      data: {
        owner,
        canteens,
        hasCanteens: canteens.length > 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/admin/owners/:ownerId/approve
 * Super Admin only
 */
const approveOwner = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.params.ownerId);

    if (!owner) {
      return res.status(404).json({
        success: false,
        message: "Owner registration not found",
      });
    }

    if (owner.approvalStatus === "Approved") {
      return res.status(409).json({
        success: false,
        message: "Owner is already approved",
      });
    }

    if (owner.approvalStatus === "Blocked") {
      return res.status(409).json({
        success: false,
        message: "Blocked owner cannot be approved directly",
      });
    }

    owner.approvalStatus = "Approved";
    owner.approvedAt = new Date();
    owner.rejectedAt = null;
    owner.rejectionReason = null;

    await owner.save();

    return res.status(200).json({
      success: true,
      message: "Owner registration approved successfully",
      data: {
        owner,
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * PATCH /api/admin/owners/:ownerId/reject
 * Super Admin only
 */
const rejectOwner = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.params.ownerId);

    if (!owner) {
      return res.status(404).json({
        success: false,
        message: "Owner registration not found",
      });
    }

    if (owner.approvalStatus === "Approved") {
      return res.status(409).json({
        success: false,
        message: "An approved owner cannot be rejected",
      });
    }

    if (owner.approvalStatus === "Blocked") {
      return res.status(409).json({
        success: false,
        message: "A blocked owner cannot be rejected",
      });
    }

    owner.approvalStatus = "Rejected";
    owner.rejectionReason = req.body.reason.trim();
    owner.rejectedAt = new Date();
    owner.approvedAt = null;

    await owner.save();

    return res.status(200).json({
      success: true,
      message: "Owner registration rejected",
      data: {
        owner,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAdminOverview,
  getPendingOwners,
  getOwners,
  getOwnerById,
  approveOwner,
  rejectOwner,
};
