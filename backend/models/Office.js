const mongoose = require("mongoose");

const officeSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Owner",
      required: [true, "Owner ID is required"],
      index: true,
    },

    canteenIds: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Canteen",
        },
      ],
      required: [true, "At least one canteen is required"],
      validate: {
        validator(canteens) {
          return Array.isArray(canteens) && canteens.length > 0;
        },
        message: "At least one canteen is required",
      },
    },

    companyName: {
      type: String,
      required: [true, "Company name is required"],
      trim: true,
      minlength: [2, "Company name must contain at least 2 characters"],
      maxlength: [150, "Company name cannot exceed 150 characters"],
    },

    building: {
      type: String,
      required: [true, "Building is required"],
      trim: true,
      maxlength: [120, "Building cannot exceed 120 characters"],
    },

    floor: {
      type: String,
      trim: true,
      maxlength: [50, "Floor cannot exceed 50 characters"],
      default: "",
    },

    address: {
      type: String,
      required: [true, "Office address is required"],
      trim: true,
      maxlength: [300, "Address cannot exceed 300 characters"],
    },

    city: {
      type: String,
      required: [true, "City is required"],
      trim: true,
      maxlength: [80, "City cannot exceed 80 characters"],
    },

    state: {
      type: String,
      required: [true, "State is required"],
      trim: true,
      maxlength: [80, "State cannot exceed 80 characters"],
    },

    pincode: {
      type: String,
      required: [true, "Pincode is required"],
      trim: true,
      match: [/^[1-9]\d{5}$/, "Please provide a valid 6-digit pincode"],
    },

    contactPerson: {
      type: String,
      required: [true, "Contact person is required"],
      trim: true,
      minlength: [2, "Contact person must contain at least 2 characters"],
      maxlength: [80, "Contact person cannot exceed 80 characters"],
    },

    contactNumber: {
      type: String,
      required: [true, "Contact number is required"],
      trim: true,
      match: [/^[6-9]\d{9}$/, "Please provide a valid contact number"],
    },

    officeCode: {
      type: String,
      required: [true, "Office code is required"],
      unique: true,
      uppercase: true,
      trim: true,
      index: true,
      immutable: true,
    },

    orderingUrl: {
      type: String,
      required: [true, "Ordering URL is required"],
      trim: true,
      immutable: true,
    },

    qrCode: {
      type: String,
      required: [true, "QR code is required"],
      immutable: true,
    },

    status: {
      type: String,
      enum: ["Active", "Inactive"],
      default: "Active",
      index: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

officeSchema.index({
  ownerId: 1,
  status: 1,
  createdAt: -1,
});

officeSchema.index({
  ownerId: 1,
  canteenIds: 1,
});

const Office = mongoose.model("Office", officeSchema);

module.exports = Office;