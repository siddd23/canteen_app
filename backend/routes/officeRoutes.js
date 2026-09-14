const express = require("express");
const { body, param } = require("express-validator");

const protect = require("../middleware/authMiddleware");
const authorizeRoles = require("../middleware/roleMiddleware");
const validateRequest = require("../middleware/validationMiddleware");

const {
  createOffice,
  getMyOffices,
  getMyOfficeById,
  updateOfficeCanteens,
  updateOfficeStatus,
} = require("../controllers/officeController");

const router = express.Router();

router.use(protect);
router.use(authorizeRoles("canteen_owner"));

const officeIdValidation = [
  param("officeId").isMongoId().withMessage("Invalid office ID"),
];

const canteenIdsValidation = [
  body("canteenIds")
    .isArray({ min: 1 })
    .withMessage("Select at least one canteen"),

  body("canteenIds.*")
    .isMongoId()
    .withMessage("One or more canteen IDs are invalid"),
];

const officeValidation = [
  body("companyName")
    .trim()
    .isLength({ min: 2, max: 150 })
    .withMessage(
      "Company name must contain between 2 and 150 characters",
    ),

  body("building")
    .trim()
    .notEmpty()
    .withMessage("Building is required")
    .isLength({ max: 120 })
    .withMessage("Building cannot exceed 120 characters"),

  body("floor")
    .optional()
    .trim()
    .isLength({ max: 50 })
    .withMessage("Floor cannot exceed 50 characters"),

  body("address")
    .trim()
    .notEmpty()
    .withMessage("Office address is required")
    .isLength({ max: 300 })
    .withMessage("Address cannot exceed 300 characters"),

  body("city")
    .trim()
    .notEmpty()
    .withMessage("City is required")
    .isLength({ max: 80 })
    .withMessage("City cannot exceed 80 characters"),

  body("state")
    .trim()
    .notEmpty()
    .withMessage("State is required")
    .isLength({ max: 80 })
    .withMessage("State cannot exceed 80 characters"),

  body("pincode")
    .trim()
    .matches(/^[1-9]\d{5}$/)
    .withMessage("Please provide a valid 6-digit pincode"),

  body("contactPerson")
    .trim()
    .isLength({ min: 2, max: 80 })
    .withMessage(
      "Contact person must contain between 2 and 80 characters",
    ),

  body("contactNumber")
    .trim()
    .matches(/^[6-9]\d{9}$/)
    .withMessage("Please provide a valid 10-digit contact number"),

  ...canteenIdsValidation,
];

router
  .route("/")
  .post(officeValidation, validateRequest, createOffice)
  .get(getMyOffices);

router.get(
  "/:officeId",
  officeIdValidation,
  validateRequest,
  getMyOfficeById,
);

router.patch(
  "/:officeId/canteens",
  [...officeIdValidation, ...canteenIdsValidation],
  validateRequest,
  updateOfficeCanteens,
);

router.patch(
  "/:officeId/status",
  [
    ...officeIdValidation,
    body("status")
      .isIn(["Active", "Inactive"])
      .withMessage("Status must be Active or Inactive"),
  ],
  validateRequest,
  updateOfficeStatus,
);

module.exports = router;