const mongoose = require("mongoose");

const orderItemSchema = new mongoose.Schema(
  {
    menuItemId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MenuItem",
      required: true,
    },
    name: { type: String, required: true, trim: true },
    unitPrice: { type: Number, required: true, min: 0 },
    quantity: { type: Number, required: true, min: 1, max: 20 },
    lineTotal: { type: Number, required: true, min: 0 },
  },
  { _id: false },
);

const orderSchema = new mongoose.Schema(
  {
    orderNumber: {
      type: String,
      required: true,
      unique: true,
      uppercase: true,
      trim: true,
      index: true,
      immutable: true,
    },
    trackingTokenHash: {
      type: String,
      select: false,
      immutable: true,
    },
    trackingTokenIssuedAt: {
      type: Date,
      immutable: true,
    },
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Owner",
      required: true,
      index: true,
      immutable: true,
    },
    customerId: { type: mongoose.Schema.Types.ObjectId, ref: "Customer", default: null, index: true, immutable: true },
    orderSource: {
      type: String,
      enum: ["office_qr", "canteen_master_qr"],
      default: "office_qr",
      index: true,
      immutable: true,
    },
    officeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Office",
      required() {
        return this.orderSource === "office_qr";
      },
      index: true,
      immutable: true,
    },
    canteenId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Canteen",
      required: true,
      index: true,
      immutable: true,
    },
    officeSnapshot: {
      companyName: { type: String, default: "" },
      officeCode: { type: String, default: "" },
      building: { type: String, default: "" },
      floor: { type: String, default: "" },
      address: { type: String, default: "" },
      city: { type: String, default: "" },
    },
    deliveryAddress: {
      buildingName: { type: String, trim: true, default: "" },
      floorOrRoom: { type: String, trim: true, default: "" },
      streetArea: { type: String, trim: true, default: "" },
      landmark: { type: String, trim: true, default: "" },
      city: { type: String, trim: true, default: "" },
      pincode: { type: String, trim: true, default: "" },
    },
    canteenSnapshot: {
      name: { type: String, required: true },
    },
    customerName: {
      type: String,
      required: [true, "Employee name is required"],
      trim: true,
      minlength: [2, "Employee name must contain at least 2 characters"],
      maxlength: [80, "Employee name cannot exceed 80 characters"],
    },
    employeeKey: {
      type: String,
      trim: true,
      lowercase: true,
      index: true,
    },
    mobile: {
      type: String,
      required: [true, "Mobile number is required"],
      trim: true,
      match: [/^[6-9]\d{9}$/, "Please provide a valid mobile number"],
      index: true,
    },
    customerNote: {
      type: String,
      trim: true,
      maxlength: [300, "Instructions cannot exceed 300 characters"],
      default: "",
    },
    items: {
      type: [orderItemSchema],
      required: true,
      validate: {
        validator(items) {
          return Array.isArray(items) && items.length > 0;
        },
        message: "At least one order item is required",
      },
    },
    itemCount: { type: Number, required: true, min: 1 },
    subtotal: { type: Number, required: true, min: 0 },
    grandTotal: { type: Number, required: true, min: 0 },
    estimatedPreparationTime: { type: Number, default: 0, min: 0 },
    orderStatus: {
      type: String,
      enum: ["Pending", "Accepted", "Delivered", "Rejected", "Cancelled"],
      default: "Pending",
      index: true,
    },
    paymentStatus: {
      type: String,
      enum: ["Unpaid", "Paid", "PayLater", "Voided"],
      default: "Unpaid",
      index: true,
    },
    fulfillmentType: { type: String, enum: ["asap", "scheduled"], default: "asap", index: true },
    scheduledFor: { type: Date, default: null, index: true },
    scheduledSlot: { type: String, trim: true, maxlength: 40, default: "" },
    acceptedAt: { type: Date, default: null },
    deliveredAt: { type: Date, default: null },
    rejectedAt: { type: Date, default: null },
    cancelledAt: { type: Date, default: null },
    paidAt: { type: Date, default: null },
  },
  { timestamps: true, versionKey: false },
);

orderSchema.index({ ownerId: 1, canteenId: 1, createdAt: -1 });
orderSchema.index({ canteenId: 1, orderStatus: 1, createdAt: -1 });
orderSchema.index({ canteenId: 1, paymentStatus: 1, deliveredAt: -1 });
orderSchema.index({ customerId: 1, createdAt: -1 });
orderSchema.index({ fulfillmentType: 1, scheduledFor: 1, orderStatus: 1 });

orderSchema.pre("validate", function setEmployeeKey() {
  if (this.customerName && this.mobile) {
    const normalizedName = this.customerName
      .trim()
      .toLowerCase()
      .replace(/\s+/g, " ");

    this.employeeKey = `${normalizedName}:${this.mobile.trim()}`;
  }
});

module.exports = mongoose.model("Order", orderSchema);
