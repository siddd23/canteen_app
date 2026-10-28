const express = require("express");
const { body } = require("express-validator");
const validateRequest = require("../middleware/validationMiddleware");
const { customerProtect } = require("../middleware/customerAuthMiddleware");
const { signup, login, profile, updateProfile, orders } = require("../controllers/customerController");

const canteenLinks = require("../controllers/customerCanteenController");
const router = express.Router();
router.post("/signup", [
  body("name").trim().isLength({ min: 2, max: 80 }),
  body("mobile").trim().matches(/^[6-9]\d{9}$/),
  body("email").optional({ checkFalsy: true }).trim().isEmail().normalizeEmail(),
  body("officeId").optional({ checkFalsy: true }).trim().isLength({ max: 50 }),
  body("password").isLength({ min: 8, max: 72 }).matches(/^(?=.*[A-Za-z])(?=.*\d).+$/).withMessage("Password must contain letters and numbers"),
], validateRequest, signup);
router.post("/login", [
  body("mobile").trim().matches(/^[6-9]\d{9}$/),
  body("password").isString().notEmpty(),
], validateRequest, login);
router.get("/me", customerProtect, profile);
router.patch("/me", customerProtect, [
  body("name").trim().isLength({ min: 2, max: 80 }),
  body("mobile").trim().matches(/^[6-9]\d{9}$/),
  body("email").optional({ checkFalsy: true }).trim().isEmail().normalizeEmail(),
  body("officeId").optional({ checkFalsy: true }).trim().isLength({ max: 50 }),
], validateRequest, updateProfile);
router.get("/canteens", customerProtect, canteenLinks.list);
router.post("/canteens", customerProtect, [
  body("code").isString().trim().toUpperCase().matches(/^CNT-[A-F0-9]{8}$/)
    .withMessage("Enter a valid canteen code (CNT-XXXXXXXX)"),
], validateRequest, canteenLinks.add);
router.delete("/canteens/:id", customerProtect, [
  require("express-validator").param("id").isMongoId(),
], validateRequest, canteenLinks.remove);
router.get("/orders", customerProtect, orders);
module.exports = router;
