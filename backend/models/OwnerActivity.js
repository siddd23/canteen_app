const mongoose = require("mongoose");

const ownerActivitySchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Owner",
      required: true,
      index: true,
    },
    action: {
      type: String,
      enum: ["ProfileUpdated", "PreferencesUpdated", "PasswordChanged"],
      required: true,
      index: true,
    },
    changedFields: {
      type: [String],
      default: [],
    },
    ipAddress: {
      type: String,
      default: "",
    },
    userAgent: {
      type: String,
      maxlength: 500,
      default: "",
    },
  },
  { timestamps: true, versionKey: false },
);

ownerActivitySchema.index({ ownerId: 1, createdAt: -1 });

module.exports = mongoose.model("OwnerActivity", ownerActivitySchema);
