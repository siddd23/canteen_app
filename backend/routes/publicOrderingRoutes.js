const express = require("express");
const { body, param, query } = require("express-validator");

const validateRequest = require("../middleware/validationMiddleware");
const {
  resolveOfficeQr,
  getPublicCanteenMenu,
  createPublicOrder,
  trackPublicOrder,
  resolveCanteenMasterQr,
  getMasterCanteenMenu,
  createMasterQrOrder,
} = require("../controllers/publicOrderingController");

const router = express.Router();

const officeCodeValidation = [
  param("officeCode")
    .trim()
    .toUpperCase()
    .matches(/^OFC-[A-F0-9]{8}$/)
    .withMessage("Invalid office QR code"),
];

const canteenCodeValidation = [
  param("publicCode")
    .trim()
    .toUpperCase()
    .matches(/^CNT-[A-F0-9]{8}$/)
    .withMessage("Invalid canteen master QR code"),
];

const masterOrderValidation = [
  ...canteenCodeValidation,
  body("customerName").trim().isLength({ min: 2, max: 80 })
    .withMessage("Employee name must contain between 2 and 80 characters"),
  body("mobile").trim().matches(/^[6-9]\d{9}$/)
    .withMessage("Please provide a valid 10-digit mobile number"),
  body("customerNote").optional().trim().isLength({ max: 300 })
    .withMessage("Instructions cannot exceed 300 characters"),
  body("deliveryAddress.buildingName").trim().isLength({ min: 2, max: 120 })
    .withMessage("Building or office name is required"),
  body("deliveryAddress.floorOrRoom").trim().isLength({ min: 1, max: 80 })
    .withMessage("Floor, room or desk is required"),
  body("deliveryAddress.streetArea").trim().isLength({ min: 3, max: 200 })
    .withMessage("Street or area is required"),
  body("deliveryAddress.landmark").optional().trim().isLength({ max: 120 })
    .withMessage("Landmark cannot exceed 120 characters"),
  body("deliveryAddress.city").trim().isLength({ min: 2, max: 80 })
    .withMessage("City is required"),
  body("deliveryAddress.pincode").trim().matches(/^\d{6}$/)
    .withMessage("Please provide a valid 6-digit PIN code"),
  body("items").isArray({ min: 1, max: 50 })
    .withMessage("Add between 1 and 50 menu items"),
  body("items.*.menuItemId").isMongoId().withMessage("Invalid menu item ID"),
  body("items.*.quantity").isInt({ min: 1, max: 20 })
    .withMessage("Item quantity must be between 1 and 20").toInt(),
];

router.get(
  "/canteens/:publicCode",
  canteenCodeValidation,
  validateRequest,
  resolveCanteenMasterQr,
);

router.get(
  "/canteens/:publicCode/menu",
  canteenCodeValidation,
  validateRequest,
  getMasterCanteenMenu,
);

router.post(
  "/canteens/:publicCode/orders",
  masterOrderValidation,
  validateRequest,
  createMasterQrOrder,
);

router.get(
  "/offices/:officeCode",
  officeCodeValidation,
  validateRequest,
  resolveOfficeQr,
);

router.post(
  "/orders",
  [
    body("officeCode")
      .trim()
      .toUpperCase()
      .matches(/^OFC-[A-F0-9]{8}$/)
      .withMessage("Invalid office QR code"),
    body("canteenId").isMongoId().withMessage("Invalid canteen ID"),
    body("customerName")
      .trim()
      .isLength({ min: 2, max: 80 })
      .withMessage("Employee name must contain between 2 and 80 characters"),
    body("mobile")
      .trim()
      .matches(/^[6-9]\d{9}$/)
      .withMessage("Please provide a valid 10-digit mobile number"),
    body("customerNote")
      .optional()
      .trim()
      .isLength({ max: 300 })
      .withMessage("Instructions cannot exceed 300 characters"),
    body("items")
      .isArray({ min: 1, max: 50 })
      .withMessage("Add between 1 and 50 menu items"),
    body("items.*.menuItemId")
      .isMongoId()
      .withMessage("Invalid menu item ID"),
    body("items.*.quantity")
      .isInt({ min: 1, max: 20 })
      .withMessage("Item quantity must be between 1 and 20")
      .toInt(),
  ],
  validateRequest,
  createPublicOrder,
);

router.get(
  "/orders/:orderNumber/track",
  [
    param("orderNumber")
      .trim()
      .toUpperCase()
      .matches(/^ORD-[A-Z0-9]+-[A-F0-9]{6}$/)
      .withMessage("Invalid order number"),
    query("token")
      .isString()
      .matches(/^[a-f0-9]{64}$/i)
      .withMessage("Invalid tracking token"),
  ],
  validateRequest,
  trackPublicOrder,
);

router.get(
  "/offices/:officeCode/canteens/:canteenId/menu",
  [
    ...officeCodeValidation,
    param("canteenId").isMongoId().withMessage("Invalid canteen ID"),
  ],
  validateRequest,
  getPublicCanteenMenu,
);

module.exports = router;
