const express = require("express");
const { body, param, query } = require("express-validator");

const {
  getMyOrders,
  updateOrderStatus,
  updatePaymentStatus,
  getPayLaterEmployees,
  settleEmployeePayLater,
  getDashboardSummary,
  getOrderNotifications,
  getOrderHistory,
  getSalesReport,
} = require("../controllers/orderController");
const protect = require("../middleware/authMiddleware");
const authorizeRoles = require("../middleware/roleMiddleware");
const validateRequest = require("../middleware/validationMiddleware");

const router = express.Router();
router.use(protect, authorizeRoles("canteen_owner"));

router.get(
  "/dashboard-summary",
  [query("canteenId").isMongoId().withMessage("Valid canteen ID is required")],
  validateRequest,
  getDashboardSummary,
);

router.get(
  "/notifications",
  [
    query("after")
      .optional()
      .isISO8601()
      .withMessage("Notification checkpoint must be a valid date"),
  ],
  validateRequest,
  getOrderNotifications,
);

router.get(
  "/history",
  [
    query("canteenId").optional().isMongoId().withMessage("Invalid canteen ID"),
    query("status")
      .optional()
      .isIn(["Pending", "Accepted", "Delivered", "Rejected", "Cancelled"])
      .withMessage("Invalid order status"),
    query("paymentStatus")
      .optional()
      .isIn(["Unpaid", "Paid", "PayLater"])
      .withMessage("Invalid payment status"),
    query("dateFrom").optional().isISO8601().withMessage("Invalid from date"),
    query("dateTo").optional().isISO8601().withMessage("Invalid to date"),
    query("search").optional().trim().isLength({ max: 100 }).withMessage("Search is too long"),
    query("page").optional().isInt({ min: 1 }).withMessage("Invalid page"),
    query("limit").optional().isInt({ min: 1, max: 50 }).withMessage("Invalid page size"),
  ],
  validateRequest,
  getOrderHistory,
);

router.get(
  "/reports",
  [
    query("canteenId").optional().isMongoId().withMessage("Invalid canteen ID"),
    query("dateFrom").optional().isISO8601().withMessage("Invalid from date"),
    query("dateTo").optional().isISO8601().withMessage("Invalid to date"),
  ],
  validateRequest,
  getSalesReport,
);

router.get(
  "/pay-later",
  [query("canteenId").optional().isMongoId().withMessage("Invalid canteen ID")],
  validateRequest,
  getPayLaterEmployees,
);

router.patch(
  "/pay-later/settle",
  [
    body("customerName").trim().isLength({ min: 2, max: 80 }).withMessage("Valid employee name is required"),
    body("mobile").matches(/^[6-9]\d{9}$/).withMessage("Valid mobile number is required"),
    body("canteenId").optional().isMongoId().withMessage("Invalid canteen ID"),
  ],
  validateRequest,
  settleEmployeePayLater,
);

router.get(
  "/",
  [
    query("canteenId").optional().isMongoId().withMessage("Invalid canteen ID"),
    query("status").optional().isIn(["Pending", "Accepted", "Delivered", "Rejected", "Cancelled"]).withMessage("Invalid order status"),
    query("paymentStatus").optional().isIn(["Unpaid", "Paid", "PayLater"]).withMessage("Invalid payment status"),
  ],
  validateRequest,
  getMyOrders,
);

router.patch(
  "/:orderId/status",
  [
    param("orderId").isMongoId().withMessage("Invalid order ID"),
    body("status").isIn(["Accepted", "Delivered", "Rejected"]).withMessage("Invalid order status"),
  ],
  validateRequest,
  updateOrderStatus,
);

router.patch(
  "/:orderId/payment",
  [
    param("orderId").isMongoId().withMessage("Invalid order ID"),
    body("status").isIn(["Paid", "PayLater"]).withMessage("Invalid payment status"),
  ],
  validateRequest,
  updatePaymentStatus,
);

module.exports = router;
