const express = require("express");
const { body, param } = require("express-validator");

const protect = require("../middleware/authMiddleware");
const authorizeRoles = require("../middleware/roleMiddleware");
const validateRequest = require("../middleware/validationMiddleware");

const {
  getAdminOverview,
  getPendingOwners,
  getOwners,
  getOwnerById,
  approveOwner,
  rejectOwner,
} = require("../controllers/ownerController");

const router = express.Router();

/*
 * Every route below requires a valid Super Admin JWT.
 */
router.use(protect);
router.use(authorizeRoles("super_admin"));

router.get("/overview", getAdminOverview);

router.get("/pending", getPendingOwners);

router.get("/", getOwners);

router.get(
  "/:ownerId",
  [
    param("ownerId")
      .isMongoId()
      .withMessage("Invalid owner ID"),
  ],
  validateRequest,
  getOwnerById
);

router.patch(
  "/:ownerId/approve",
  [
    param("ownerId")
      .isMongoId()
      .withMessage("Invalid owner ID"),
  ],
  validateRequest,
  approveOwner
);

router.patch(
  "/:ownerId/reject",
  [
    param("ownerId")
      .isMongoId()
      .withMessage("Invalid owner ID"),

    body("reason")
      .trim()
      .notEmpty()
      .withMessage("Rejection reason is required")
      .isLength({ min: 5, max: 500 })
      .withMessage(
        "Rejection reason must contain between 5 and 500 characters"
      ),
  ],
  validateRequest,
  rejectOwner
);

module.exports = router;
