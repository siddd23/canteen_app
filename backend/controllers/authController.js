const crypto = require("crypto");

const Owner = require("../models/Owner");
const Canteen = require("../models/Canteen");
const generateToken = require("../utils/generateToken");

const normalizeEmail = (email) => email.trim().toLowerCase();

const safeCompare = (firstValue, secondValue) => {
  const firstBuffer = Buffer.from(String(firstValue));
  const secondBuffer = Buffer.from(String(secondValue));

  if (firstBuffer.length !== secondBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(firstBuffer, secondBuffer);
};

/*
 * POST /api/auth/register
 * Public
 */
const registerOwner = async (req, res, next) => {
  try {
    const {
      name,
      businessName,
      email,
      mobile,
      password,
    } = req.body;

    const normalizedEmail = normalizeEmail(email);
    const normalizedMobile = mobile.trim();

    const superAdminEmail = normalizeEmail(
      process.env.SUPER_ADMIN_EMAIL || ""
    );

    if (normalizedEmail === superAdminEmail) {
      return res.status(409).json({
        success: false,
        message: "An account already exists with this email address",
      });
    }

    const existingOwner = await Owner.findOne({
      $or: [
        { email: normalizedEmail },
        { mobile: normalizedMobile },
      ],
    });

    if (existingOwner) {
      const duplicateField =
        existingOwner.email === normalizedEmail
          ? "email address"
          : "mobile number";

      return res.status(409).json({
        success: false,
        message: `An account already exists with this ${duplicateField}`,
      });
    }

    const owner = await Owner.create({
      name: name.trim(),
      businessName: businessName.trim(),
      email: normalizedEmail,
      mobile: normalizedMobile,
      password,
    });

    return res.status(201).json({
      success: true,
      message:
        "Registration submitted successfully. Please wait for Super Admin approval.",
      data: {
        owner: {
          id: owner._id,
          name: owner.name,
          businessName: owner.businessName,
          email: owner.email,
          mobile: owner.mobile,
          role: owner.role,
          approvalStatus: owner.approvalStatus,
          createdAt: owner.createdAt,
        },
        destination: "approval_pending",
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * POST /api/auth/login
 * Public
 */
const login = async (req, res, next) => {
  try {
    const email = normalizeEmail(req.body.email);
    const password = req.body.password;

    const superAdminEmail = normalizeEmail(
      process.env.SUPER_ADMIN_EMAIL || ""
    );

    /*
     * First check whether the credentials belong to the Super Admin.
     */
    if (email === superAdminEmail) {
      const superAdminPassword =
        process.env.SUPER_ADMIN_PASSWORD || "";

      if (!safeCompare(password, superAdminPassword)) {
        return res.status(401).json({
          success: false,
          message: "Invalid email or password",
        });
      }

      const token = generateToken({
        id: "super-admin",
        role: "super_admin",
      });

      return res.status(200).json({
        success: true,
        message: "Login successful",
        data: {
          token,
          user: {
            id: "super-admin",
            name:
              process.env.SUPER_ADMIN_NAME || "Super Admin",
            email: superAdminEmail,
            role: "super_admin",
          },
          destination: "admin_dashboard",
        },
      });
    }

    /*
     * Otherwise, check for a registered canteen owner.
     * Password must be explicitly selected because the model uses
     * select: false.
     */
    const owner = await Owner.findOne({ email }).select("+password");

    if (!owner) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    const passwordMatches = await owner.comparePassword(password);

    if (!passwordMatches) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    /*
     * Pending, rejected and blocked accounts do not receive an access token.
     */
    if (owner.approvalStatus === "Pending") {
      return res.status(200).json({
        success: true,
        message: "Your registration is awaiting approval",
        data: {
          token: null,
          user: {
            id: owner._id,
            name: owner.name,
            email: owner.email,
            role: owner.role,
            approvalStatus: owner.approvalStatus,
          },
          destination: "approval_pending",
        },
      });
    }

    if (owner.approvalStatus === "Rejected") {
      return res.status(200).json({
        success: true,
        message: "Your registration was rejected",
        data: {
          token: null,
          user: {
            id: owner._id,
            name: owner.name,
            email: owner.email,
            role: owner.role,
            approvalStatus: owner.approvalStatus,
            rejectionReason: owner.rejectionReason,
          },
          destination: "registration_rejected",
        },
      });
    }

    if (owner.approvalStatus === "Blocked") {
      return res.status(403).json({
        success: false,
        message: "Your account has been blocked. Contact support.",
        data: {
          destination: "account_blocked",
        },
      });
    }

    /*
     * The owner is approved. Check automatically whether the owner
     * already has one or more canteens.
     */
    const hasCanteens = Boolean(
      await Canteen.exists({
        ownerId: owner._id,
      })
    );

    owner.lastLoginAt = new Date();
    await owner.save({ validateBeforeSave: false });

    const token = generateToken({
      id: owner._id.toString(),
      role: owner.role,
    });

    return res.status(200).json({
      success: true,
      message: "Login successful",
      data: {
        token,
        user: {
          id: owner._id,
          name: owner.name,
          businessName: owner.businessName,
          email: owner.email,
          mobile: owner.mobile,
          role: owner.role,
          approvalStatus: owner.approvalStatus,
          hasCanteens,
        },
        destination: hasCanteens
          ? "owner_dashboard"
          : "create_canteen",
      },
    });
  } catch (error) {
    next(error);
  }
};

/*
 * GET /api/session
 * Protected session validation used when the application starts.
 */
const getSession = async (req, res, next) => {
  try {
    if (req.user.role === "super_admin") {
      return res.status(200).json({
        success: true,
        data: {
          user: req.user,
          destination: "admin_dashboard",
        },
      });
    }

    const hasCanteens = Boolean(
      await Canteen.exists({ ownerId: req.user.id }),
    );

    return res.status(200).json({
      success: true,
      data: {
        user: {
          id: req.user.owner._id,
          name: req.user.owner.name,
          businessName: req.user.owner.businessName,
          email: req.user.owner.email,
          mobile: req.user.owner.mobile,
          role: req.user.owner.role,
          approvalStatus: req.user.owner.approvalStatus,
          hasCanteens,
        },
        destination: hasCanteens ? "owner_dashboard" : "create_canteen",
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerOwner,
  login,
  getSession,
};
