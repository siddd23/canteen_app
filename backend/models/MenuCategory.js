const mongoose = require("mongoose");

const menuCategorySchema = new mongoose.Schema(
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

    name: {
      type: String,
      required: [true, "Category name is required"],
      trim: true,
      minlength: [2, "Category name must contain at least 2 characters"],
      maxlength: [60, "Category name cannot exceed 60 characters"],
    },

    displayOrder: {
      type: Number,
      default: 0,
      min: [0, "Display order cannot be negative"],
      max: [999, "Display order cannot exceed 999"],
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

menuCategorySchema.index(
  {
    canteenId: 1,
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

menuCategorySchema.index({
  canteenId: 1,
  status: 1,
  displayOrder: 1,
});

const MenuCategory = mongoose.model("MenuCategory", menuCategorySchema);

module.exports = MenuCategory;
