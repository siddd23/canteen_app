const express = require("express");
const { body } = require("express-validator");

const {
  registerOwner,
  login,
} = require("../controllers/authController");

const validateRequest = require("../middleware/validationMiddleware");

const router = express.Router();

router.post(
  "/register",
  [
    body("name")
      .trim()
      .notEmpty()
      .withMessage("Owner name is required")
      .isLength({ min: 2, max: 80 })
      .withMessage("Owner name must contain between 2 and 80 characters"),

    body("businessName")
      .trim()
      .notEmpty()
      .withMessage("Business name is required")
      .isLength({ min: 2, max: 120 })
      .withMessage(
        "Business name must contain between 2 and 120 characters"
      ),

    body("email")
      .trim()
      .notEmpty()
      .withMessage("Email is required")
      .isEmail()
      .withMessage("Please provide a valid email address")
      .normalizeEmail(),

    body("mobile")
      .trim()
      .matches(/^[6-9]\d{9}$/)
      .withMessage("Please provide a valid 10-digit mobile number"),

    body("password")
      .isString()
      .isLength({ min: 8, max: 128 })
      .withMessage(
        "Password must contain between 8 and 128 characters"
      ),
  ],
  validateRequest,
  registerOwner
);

router.post(
  "/login",
  [
    body("email")
      .trim()
      .notEmpty()
      .withMessage("Email is required")
      .isEmail()
      .withMessage("Please provide a valid email address")
      .normalizeEmail(),

    body("password")
      .isString()
      .notEmpty()
      .withMessage("Password is required"),
  ],
  validateRequest,
  login
);

module.exports = router;