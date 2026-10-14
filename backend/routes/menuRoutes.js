const express = require("express");
const { body, param } = require("express-validator");

const protect = require("../middleware/authMiddleware");
const authorizeRoles = require("../middleware/roleMiddleware");
const validateRequest = require("../middleware/validationMiddleware");

const {
  getMyCanteenMenu,
  createMenuCategory,
  updateMenuCategory,
  deleteMenuCategory,
  createMenuItem,
  updateMenuItem,
  deleteMenuItem,
  updateMenuItemAvailability,
} = require("../controllers/menuController");

const router = express.Router();

router.use(protect);
router.use(authorizeRoles("canteen_owner"));

const canteenIdValidation = [
  param("canteenId").isMongoId().withMessage("Invalid canteen ID"),
];

const categoryIdValidation = [
  param("categoryId").isMongoId().withMessage("Invalid category ID"),
];

const itemIdValidation = [
  param("itemId").isMongoId().withMessage("Invalid menu item ID"),
];

const categoryCreateValidation = [
  body("name")
    .trim()
    .isLength({ min: 2, max: 60 })
    .withMessage("Category name must contain between 2 and 60 characters"),

  body("displayOrder")
    .optional()
    .isInt({ min: 0, max: 999 })
    .withMessage("Display order must be between 0 and 999"),

  body("status")
    .optional()
    .isIn(["Active", "Inactive"])
    .withMessage("Status must be Active or Inactive"),
];

const categoryUpdateValidation = [
  body("name")
    .optional()
    .trim()
    .isLength({ min: 2, max: 60 })
    .withMessage("Category name must contain between 2 and 60 characters"),

  body("displayOrder")
    .optional()
    .isInt({ min: 0, max: 999 })
    .withMessage("Display order must be between 0 and 999"),

  body("status")
    .optional()
    .isIn(["Active", "Inactive"])
    .withMessage("Status must be Active or Inactive"),
];

const menuItemCreateValidation = [
  body("categoryId")
    .isMongoId()
    .withMessage("A valid category ID is required"),

  body("name")
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage("Item name must contain between 2 and 100 characters"),

  body("description")
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage("Description cannot exceed 500 characters"),

  body("price")
    .isFloat({ min: 0, max: 100000 })
    .withMessage("Price must be between 0 and 100000"),

  body("foodType")
    .optional()
    .isIn(["Vegetarian", "Non-Vegetarian"])
    .withMessage("Food type must be Vegetarian or Non-Vegetarian"),

  body("preparationTime")
    .optional()
    .isInt({ min: 0, max: 180 })
    .withMessage("Preparation time must be between 0 and 180 minutes"),

  body("imageUrl")
    .optional({ values: "falsy" })
    .trim()
    .isURL({ protocols: ["http", "https"], require_protocol: true })
    .withMessage("Image URL must be a valid HTTP or HTTPS URL")
    .isLength({ max: 1000 })
    .withMessage("Image URL cannot exceed 1000 characters"),

  body("isAvailable")
    .optional()
    .isBoolean()
    .withMessage("Availability must be true or false"),
  body("availableDays").optional().isArray({ min: 1, max: 7 })
    .withMessage("Select between one and seven menu days"),
  body("availableDays.*").optional().isIn(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    .withMessage("Invalid menu day"),
];

const menuItemUpdateValidation = [
  body("categoryId")
    .optional()
    .isMongoId()
    .withMessage("Category ID must be valid"),

  body("name")
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage("Item name must contain between 2 and 100 characters"),

  body("description")
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage("Description cannot exceed 500 characters"),

  body("price")
    .optional()
    .isFloat({ min: 0, max: 100000 })
    .withMessage("Price must be between 0 and 100000"),

  body("foodType")
    .optional()
    .isIn(["Vegetarian", "Non-Vegetarian"])
    .withMessage("Food type must be Vegetarian or Non-Vegetarian"),

  body("preparationTime")
    .optional()
    .isInt({ min: 0, max: 180 })
    .withMessage("Preparation time must be between 0 and 180 minutes"),

  body("imageUrl")
    .optional({ values: "falsy" })
    .trim()
    .isURL({ protocols: ["http", "https"], require_protocol: true })
    .withMessage("Image URL must be a valid HTTP or HTTPS URL")
    .isLength({ max: 1000 })
    .withMessage("Image URL cannot exceed 1000 characters"),

  body("isAvailable")
    .optional()
    .isBoolean()
    .withMessage("Availability must be true or false"),
  body("availableDays").optional().isArray({ min: 1, max: 7 })
    .withMessage("Select between one and seven menu days"),
  body("availableDays.*").optional().isIn(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    .withMessage("Invalid menu day"),
];

router.get(
  "/:canteenId/menu",
  canteenIdValidation,
  validateRequest,
  getMyCanteenMenu,
);

router.post(
  "/:canteenId/menu/categories",
  [...canteenIdValidation, ...categoryCreateValidation],
  validateRequest,
  createMenuCategory,
);

router.patch(
  "/:canteenId/menu/categories/:categoryId",
  [
    ...canteenIdValidation,
    ...categoryIdValidation,
    ...categoryUpdateValidation,
  ],
  validateRequest,
  updateMenuCategory,
);

router.delete(
  "/:canteenId/menu/categories/:categoryId",
  [
    ...canteenIdValidation,
    ...categoryIdValidation,
    body("deleteItems")
      .optional()
      .isBoolean()
      .withMessage("deleteItems must be true or false"),
  ],
  validateRequest,
  deleteMenuCategory,
);

router.post(
  "/:canteenId/menu/items",
  [...canteenIdValidation, ...menuItemCreateValidation],
  validateRequest,
  createMenuItem,
);

router.patch(
  "/:canteenId/menu/items/:itemId",
  [...canteenIdValidation, ...itemIdValidation, ...menuItemUpdateValidation],
  validateRequest,
  updateMenuItem,
);

router.delete(
  "/:canteenId/menu/items/:itemId",
  [...canteenIdValidation, ...itemIdValidation],
  validateRequest,
  deleteMenuItem,
);

router.patch(
  "/:canteenId/menu/items/:itemId/availability",
  [
    ...canteenIdValidation,
    ...itemIdValidation,
    body("isAvailable")
      .isBoolean()
      .withMessage("Availability must be true or false"),
  ],
  validateRequest,
  updateMenuItemAvailability,
);

module.exports = router;
