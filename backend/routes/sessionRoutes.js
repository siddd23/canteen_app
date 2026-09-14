const express = require("express");

const protect = require("../middleware/authMiddleware");
const { getSession } = require("../controllers/authController");

const router = express.Router();

router.get("/", protect, getSession);

module.exports = router;
