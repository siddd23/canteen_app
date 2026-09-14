const jwt = require("jsonwebtoken");
const Owner = require("../models/Owner");

const protect = async (req, res, next) => {
  try {
    const authorization = req.headers.authorization;

    if (
      !authorization ||
      !authorization.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is required",
      });
    }

    const token = authorization.split(" ")[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is required",
      });
    }

    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET,
      {
        issuer: "canteen-app",
        audience: "canteen-app-users",
      }
    );

    /*
     * Super Admin exists in .env, not MongoDB.
     */
    if (
      decoded.role === "super_admin" &&
      decoded.id === "super-admin"
    ) {
      req.user = {
        id: "super-admin",
        name: process.env.SUPER_ADMIN_NAME || "Super Admin",
        email: process.env.SUPER_ADMIN_EMAIL,
        role: "super_admin",
      };

      return next();
    }

    /*
     * Canteen owners are loaded from MongoDB on every protected request.
     */
    if (decoded.role === "canteen_owner") {
      const owner = await Owner.findById(decoded.id).select("+passwordChangedAt");

      if (!owner) {
        return res.status(401).json({
          success: false,
          message: "The account for this token no longer exists",
        });
      }

      if (owner.approvalStatus !== "Approved") {
        return res.status(403).json({
          success: false,
          message: `Account is ${owner.approvalStatus.toLowerCase()}`,
        });
      }

      if (
        owner.passwordChangedAt &&
        decoded.iat * 1000 < owner.passwordChangedAt.getTime()
      ) {
        return res.status(401).json({
          success: false,
          message: "Password was changed. Please sign in again.",
        });
      }

      req.user = {
        id: owner._id,
        name: owner.name,
        email: owner.email,
        role: owner.role,
        owner,
      };

      return next();
    }

    return res.status(401).json({
      success: false,
      message: "Invalid authentication token",
    });
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({
        success: false,
        message: "Authentication token has expired",
      });
    }

    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({
        success: false,
        message: "Invalid authentication token",
      });
    }

    next(error);
  }
};

module.exports = protect;
