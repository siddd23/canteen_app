const express = require("express");
const { body, param } = require("express-validator");

const protect = require("../middleware/authMiddleware");
const authorizeRoles = require("../middleware/roleMiddleware");
const validateRequest = require("../middleware/validationMiddleware");

const {
  createCanteen,
  getMyCanteens,
  getMyCanteenById,
  updateMyCanteen,
  updateCanteenStatus,
  updateMasterQrStatus,
} = require("../controllers/canteenController");

const router = express.Router();

router.use(protect);
router.use(authorizeRoles("canteen_owner"));

const canteenValidation = [
  body("name")
    .trim()
    .notEmpty()
    .withMessage("Canteen name is required")
    .isLength({ min: 2, max: 120 })
    .withMessage("Canteen name must contain between 2 and 120 characters"),

  body("address")
    .trim()
    .notEmpty()
    .withMessage("Canteen address is required")
    .isLength({ max: 300 })
    .withMessage("Address cannot exceed 300 characters"),

  body("city")
    .trim()
    .notEmpty()
    .withMessage("City is required")
    .isLength({ max: 80 })
    .withMessage("City cannot exceed 80 characters"),

  body("contactNumber")
    .trim()
    .matches(/^[6-9]\d{9}$/)
    .withMessage("Please provide a valid 10-digit contact number"),

  body("openingTime")
    .trim()
    .notEmpty()
    .withMessage("Opening time is required"),

  body("closingTime")
    .trim()
    .notEmpty()
    .withMessage("Closing time is required"),

  body("serviceSlots").optional().isArray({ min: 2, max: 2 })
    .withMessage("Exactly two service slots are required"),
  body("serviceSlots.*.label").optional().trim().notEmpty().isLength({ max: 40 }),
  body("serviceSlots.*.openingTime").optional().trim().notEmpty(),
  body("serviceSlots.*.closingTime").optional().trim().notEmpty(),
];

router
  .route("/")
  .post(canteenValidation, validateRequest, createCanteen)
  .get(getMyCanteens);

router.get(
  "/:canteenId",
  [
    param("canteenId")
      .isMongoId()
      .withMessage("Invalid canteen ID"),
  ],
  validateRequest,
  getMyCanteenById
);

router.patch(
  "/:canteenId",
  [
    param("canteenId")
      .isMongoId()
      .withMessage("Invalid canteen ID"),

    body("name")
      .optional()
      .trim()
      .isLength({ min: 2, max: 120 })
      .withMessage("Canteen name must contain between 2 and 120 characters"),

    body("address")
      .optional()
      .trim()
      .notEmpty()
      .withMessage("Address cannot be empty")
      .isLength({ max: 300 })
      .withMessage("Address cannot exceed 300 characters"),

    body("city")
      .optional()
      .trim()
      .notEmpty()
      .withMessage("City cannot be empty")
      .isLength({ max: 80 })
      .withMessage("City cannot exceed 80 characters"),

    body("contactNumber")
      .optional()
      .trim()
      .matches(/^[6-9]\d{9}$/)
      .withMessage("Please provide a valid 10-digit contact number"),

    body("openingTime")
      .optional()
      .trim()
      .notEmpty()
      .withMessage("Opening time cannot be empty"),

    body("closingTime")
      .optional()
      .trim()
      .notEmpty()
      .withMessage("Closing time cannot be empty"),

    body("serviceSlots").optional().isArray({ min: 2, max: 2 })
      .withMessage("Exactly two service slots are required"),
    body("serviceSlots.*.label").optional().trim().notEmpty().isLength({ max: 40 }),
    body("serviceSlots.*.openingTime").optional().trim().notEmpty(),
    body("serviceSlots.*.closingTime").optional().trim().notEmpty(),

    body("status")
      .optional()
      .isIn(["Active", "Inactive"])
      .withMessage("Status must be Active or Inactive"),
  ],
  validateRequest,
  updateMyCanteen
);

router.patch(
  "/:canteenId/status",
  [
    param("canteenId")
      .isMongoId()
      .withMessage("Invalid canteen ID"),

    body("status")
      .isIn(["Active", "Inactive"])
      .withMessage("Status must be Active or Inactive"),
  ],
  validateRequest,
  updateCanteenStatus
);

router.patch(
  "/:canteenId/master-qr/status",
  [
    param("canteenId").isMongoId().withMessage("Invalid canteen ID"),
    body("enabled").isBoolean().withMessage("enabled must be true or false"),
  ],
  validateRequest,
  updateMasterQrStatus,
);

module.exports = router;
