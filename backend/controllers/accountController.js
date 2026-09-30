const Owner = require("../models/Owner");
const OwnerActivity = require("../models/OwnerActivity");

const publicOwner = (owner) => ({
  id: owner._id,
  name: owner.name,
  businessName: owner.businessName,
  email: owner.email,
  mobile: owner.mobile,
  role: owner.role,
  approvalStatus: owner.approvalStatus,
  preferences: {
    orderSoundEnabled: owner.preferences?.orderSoundEnabled ?? true,
    payLaterEnabled: owner.preferences?.payLaterEnabled ?? true,
    defaultPreparationTime: owner.preferences?.defaultPreparationTime ?? 15,
  },
  createdAt: owner.createdAt,
  updatedAt: owner.updatedAt,
});

const recordActivity = async (req, action, changedFields) => {
  try {
    await OwnerActivity.create({
      ownerId: req.user.id,
      action,
      changedFields,
      ipAddress: req.ip || "",
      userAgent: String(req.get("user-agent") || "").slice(0, 500),
    });
  } catch (error) {
    console.error(`Unable to record owner activity: ${error.message}`);
  }
};

const getMyProfile = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.user.id);
    return res.status(200).json({
      success: true,
      data: { owner: publicOwner(owner) },
    });
  } catch (error) {
    next(error);
  }
};

const updateMyProfile = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.user.id);
    const nextEmail = req.body.email.trim().toLowerCase();
    const nextMobile = req.body.mobile.trim();

    if (nextEmail === String(process.env.SUPER_ADMIN_EMAIL || "").toLowerCase()) {
      return res.status(409).json({
        success: false,
        message: "This email address is already in use",
      });
    }

    const duplicate = await Owner.findOne({
      _id: { $ne: owner._id },
      $or: [{ email: nextEmail }, { mobile: nextMobile }],
    }).select("email mobile");

    if (duplicate) {
      return res.status(409).json({
        success: false,
        message: duplicate.email === nextEmail
          ? "This email address is already in use"
          : "This mobile number is already in use",
      });
    }

    const updates = {
      name: req.body.name.trim(),
      businessName: req.body.businessName.trim(),
      email: nextEmail,
      mobile: nextMobile,
    };
    const changedFields = Object.keys(updates).filter(
      (field) => String(owner[field]) !== String(updates[field]),
    );
    Object.assign(owner, updates);
    await owner.save();
    if (changedFields.length > 0) {
      await recordActivity(req, "ProfileUpdated", changedFields);
    }

    return res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      data: { owner: publicOwner(owner) },
    });
  } catch (error) {
    next(error);
  }
};

const updateMyPreferences = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.user.id);
    const nextPreferences = {
      orderSoundEnabled: req.body.orderSoundEnabled,
      payLaterEnabled: req.body.payLaterEnabled,
      defaultPreparationTime: req.body.defaultPreparationTime,
    };
    const changedFields = Object.keys(nextPreferences).filter(
      (field) => owner.preferences?.[field] !== nextPreferences[field],
    );
    owner.preferences = nextPreferences;
    await owner.save();
    if (changedFields.length > 0) {
      await recordActivity(req, "PreferencesUpdated", changedFields);
    }

    return res.status(200).json({
      success: true,
      message: "Preferences updated successfully",
      data: { owner: publicOwner(owner) },
    });
  } catch (error) {
    next(error);
  }
};

const changeMyPassword = async (req, res, next) => {
  try {
    const owner = await Owner.findById(req.user.id).select("+password");
    if (!(await owner.comparePassword(req.body.currentPassword))) {
      return res.status(400).json({
        success: false,
        message: "Current password is incorrect",
      });
    }
    if (await owner.comparePassword(req.body.newPassword)) {
      return res.status(400).json({
        success: false,
        message: "New password must be different from the current password",
      });
    }

    owner.password = req.body.newPassword;
    await owner.save();
    await recordActivity(req, "PasswordChanged", ["password"]);

    return res.status(200).json({
      success: true,
      message: "Password changed successfully. Please sign in again.",
      data: { requiresLogin: true },
    });
  } catch (error) {
    next(error);
  }
};

const registerNotificationToken = async (req, res, next) => {
  try {
    const token = req.body.token.trim();
    // An FCM token identifies one app installation. If the same device signs
    // into a different owner account, move the token instead of leaving it on
    // both accounts and leaking another canteen's order notifications.
    await Owner.updateMany(
      { _id: { $ne: req.user.id }, fcmTokens: token },
      { $pull: { fcmTokens: token } },
    );
    await Owner.findByIdAndUpdate(req.user.id, {
      $addToSet: { fcmTokens: token },
    });

    return res.status(200).json({
      success: true,
      message: "Notification device registered successfully",
    });
  } catch (error) {
    next(error);
  }
};

const removeNotificationToken = async (req, res, next) => {
  try {
    const token = req.body.token.trim();
    await Owner.findByIdAndUpdate(req.user.id, {
      $pull: { fcmTokens: token },
    });

    return res.status(200).json({
      success: true,
      message: "Notification device removed successfully",
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMyProfile,
  updateMyProfile,
  updateMyPreferences,
  changeMyPassword,
  registerNotificationToken,
  removeNotificationToken,
};
