const mongoose = require("mongoose");

const canteenSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Owner",
      required: [true, "Owner ID is required"],
      index: true,
    },

    name: {
      type: String,
      required: [true, "Canteen name is required"],
      trim: true,
      minlength: [2, "Canteen name must contain at least 2 characters"],
      maxlength: [120, "Canteen name cannot exceed 120 characters"],
    },

    address: {
      type: String,
      required: [true, "Canteen address is required"],
      trim: true,
      maxlength: [300, "Address cannot exceed 300 characters"],
    },

    city: {
      type: String,
      required: [true, "City is required"],
      trim: true,
      maxlength: [80, "City cannot exceed 80 characters"],
    },

    contactNumber: {
      type: String,
      required: [true, "Contact number is required"],
      trim: true,
      match: [/^[6-9]\d{9}$/, "Please provide a valid contact number"],
    },

    openingTime: {
      type: String,
      required: [true, "Opening time is required"],
      trim: true,
    },

    closingTime: {
      type: String,
      required: [true, "Closing time is required"],
      trim: true,
    },

    status: {
      type: String,
      enum: ["Active", "Inactive"],
      default: "Active",
      index: true,
    },

    publicCode: {
      type: String,
      unique: true,
      sparse: true,
      uppercase: true,
      trim: true,
      immutable: true,
      index: true,
    },

    masterOrderingUrl: { type: String, trim: true, default: "" },
    masterQrCode: { type: String, default: "" },
    masterQrEnabled: { type: Boolean, default: true, index: true },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

/*
 * Prevent one owner from creating two canteens with the same name.
 * Different owners can still use the same canteen name.
 */
canteenSchema.index(
  {
    ownerId: 1,
    name: 1,
  },
  {
    unique: true,
    collation: {
      locale: "en",
      strength: 2,
    },
  }
);

const Canteen = mongoose.model("Canteen", canteenSchema);

module.exports = Canteen;
