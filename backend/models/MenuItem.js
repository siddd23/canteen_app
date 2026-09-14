const mongoose = require("mongoose");

const menuItemSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Owner",
      required: [true, "Owner ID is required"],
      index: true,
    },

    canteenId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Canteen",
      required: [true, "Canteen ID is required"],
      index: true,
    },

    categoryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MenuCategory",
      required: [true, "Category ID is required"],
      index: true,
    },

    name: {
      type: String,
      required: [true, "Item name is required"],
      trim: true,
      minlength: [2, "Item name must contain at least 2 characters"],
      maxlength: [100, "Item name cannot exceed 100 characters"],
    },

    description: {
      type: String,
      trim: true,
      maxlength: [500, "Description cannot exceed 500 characters"],
      default: "",
    },

    price: {
      type: Number,
      required: [true, "Price is required"],
      min: [0, "Price cannot be negative"],
      max: [100000, "Price cannot exceed 100000"],
    },

    foodType: {
      type: String,
      enum: ["Vegetarian", "Non-Vegetarian"],
      default: "Vegetarian",
      index: true,
    },

    preparationTime: {
      type: Number,
      default: 0,
      min: [0, "Preparation time cannot be negative"],
      max: [180, "Preparation time cannot exceed 180 minutes"],
    },

    imageUrl: {
      type: String,
      trim: true,
      maxlength: [1000, "Image URL cannot exceed 1000 characters"],
      default: "",
    },

    isAvailable: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

menuItemSchema.index(
  {
    canteenId: 1,
    categoryId: 1,
    name: 1,
  },
  {
    unique: true,
    collation: {
      locale: "en",
      strength: 2,
    },
  },
);

menuItemSchema.index({
  canteenId: 1,
  categoryId: 1,
  isAvailable: 1,
  name: 1,
});

const MenuItem = mongoose.model("MenuItem", menuItemSchema);

module.exports = MenuItem;
