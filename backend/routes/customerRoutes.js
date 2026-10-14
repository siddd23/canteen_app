const express = require("express");
const { body } = require("express-validator");
const validateRequest = require("../middleware/validationMiddleware");
const { customerProtect } = require("../middleware/customerAuthMiddleware");
const { signup, login, profile, orders } = require("../controllers/customerController");

const router = express.Router();
router.post("/signup", [
  body("name").trim().isLength({ min: 2, max: 80 }),
  body("mobile").trim().matches(/^[6-9]\d{9}$/),
  body("password").isLength({ min: 8, max: 72 }).matches(/^(?=.*[A-Za-z])(?=.*\d).+$/).withMessage("Password must contain letters and numbers"),
], validateRequest, signup);
router.post("/login", [
  body("mobile").trim().matches(/^[6-9]\d{9}$/),
  body("password").isString().notEmpty(),
], validateRequest, login);
router.get("/me", customerProtect, profile);
router.get("/orders", customerProtect, orders);
module.exports = router;
