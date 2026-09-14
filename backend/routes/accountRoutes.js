const express = require("express");
const { body } = require("express-validator");

const protect = require("../middleware/authMiddleware");
const authorizeRoles = require("../middleware/roleMiddleware");
const validateRequest = require("../middleware/validationMiddleware");
const {
  getMyProfile,
  updateMyProfile,
  updateMyPreferences,
  changeMyPassword,
  registerNotificationToken,
  removeNotificationToken,
} = require("../controllers/accountController");

const router = express.Router();
router.use(protect, authorizeRoles("canteen_owner"));

router.get("/profile", getMyProfile);

router.patch(
  "/profile",
  [
    body("name").trim().isLength({ min: 2, max: 80 }).withMessage("Valid owner name is required"),
    body("businessName").trim().isLength({ min: 2, max: 120 }).withMessage("Valid business name is required"),
    body("email").trim().isEmail().normalizeEmail().withMessage("Valid email is required"),
    body("mobile").trim().matches(/^[6-9]\d{9}$/).withMessage("Valid mobile number is required"),
  ],
  validateRequest,
  updateMyProfile,
);

router.patch(
  "/preferences",
  [
    body("orderSoundEnabled").isBoolean().withMessage("Order sound preference is required").toBoolean(),
    body("payLaterEnabled").isBoolean().withMessage("Pay Later preference is required").toBoolean(),
    body("defaultPreparationTime").isInt({ min: 0, max: 180 }).withMessage("Preparation time must be between 0 and 180 minutes").toInt(),
  ],
  validateRequest,
  updateMyPreferences,
);

router.patch(
  "/password",
  [
    body("currentPassword").isString().notEmpty().withMessage("Current password is required"),
    body("newPassword").isString().isLength({ min: 8, max: 128 }).withMessage("New password must contain between 8 and 128 characters"),
  ],
  validateRequest,
  changeMyPassword,
);

const notificationTokenValidation = [
  body("token")
    .isString()
    .trim()
    .isLength({ min: 20, max: 4096 })
    .withMessage("A valid notification token is required"),
];

router.post(
  "/notifications/token",
  notificationTokenValidation,
  validateRequest,
  registerNotificationToken,
);

router.post(
  "/notifications/token/remove",
  notificationTokenValidation,
  validateRequest,
  removeNotificationToken,
);

module.exports = router;
