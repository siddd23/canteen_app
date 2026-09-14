const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const ownerSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Owner name is required"],
      trim: true,
      minlength: [2, "Name must contain at least 2 characters"],
      maxlength: [80, "Name cannot exceed 80 characters"],
    },

    businessName: {
      type: String,
      required: [true, "Business name is required"],
      trim: true,
      minlength: [2, "Business name must contain at least 2 characters"],
      maxlength: [120, "Business name cannot exceed 120 characters"],
    },

    email: {
      type: String,
      required: [true, "Email is required"],
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
      match: [
        /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
        "Please provide a valid email address",
      ],
    },

    mobile: {
      type: String,
      required: [true, "Mobile number is required"],
      unique: true,
      trim: true,
      index: true,
      match: [/^[6-9]\d{9}$/, "Please provide a valid mobile number"],
    },

    password: {
      type: String,
      required: [true, "Password is required"],
      minlength: [8, "Password must contain at least 8 characters"],
      select: false,
    },

    role: {
      type: String,
      enum: ["canteen_owner"],
      default: "canteen_owner",
      immutable: true,
    },

    approvalStatus: {
      type: String,
      enum: ["Pending", "Approved", "Rejected", "Blocked"],
      default: "Pending",
      index: true,
    },

    rejectionReason: {
      type: String,
      trim: true,
      maxlength: [500, "Rejection reason cannot exceed 500 characters"],
      default: null,
    },

    approvedAt: {
      type: Date,
      default: null,
    },

    rejectedAt: {
      type: Date,
      default: null,
    },

    lastLoginAt: {
      type: Date,
      default: null,
    },

    passwordChangedAt: {
      type: Date,
      default: null,
      select: false,
    },

    fcmTokens: {
      type: [String],
      default: [],
      select: false,
    },

    preferences: {
      orderSoundEnabled: {
        type: Boolean,
        default: true,
      },
      payLaterEnabled: {
        type: Boolean,
        default: true,
      },
      defaultPreparationTime: {
        type: Number,
        min: 0,
        max: 180,
        default: 15,
      },
    },
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: {
      transform(document, returnedObject) {
        delete returnedObject.password;
        return returnedObject;
      },
    },
  }
);

ownerSchema.pre("save", async function () {
  if (!this.isModified("password")) {
    return;
  }

  if (!this.isNew) {
    this.passwordChangedAt = new Date(Date.now() - 1000);
  }

  this.password = await bcrypt.hash(this.password, 12);
});

ownerSchema.methods.comparePassword = async function (enteredPassword) {
  return bcrypt.compare(enteredPassword, this.password);
};

const Owner = mongoose.model("Owner", ownerSchema);

module.exports = Owner;
