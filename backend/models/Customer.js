const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");

const savedAddressSchema = new mongoose.Schema({
  label: { type: String, trim: true, maxlength: 30, default: 'Work' },
  buildingName: { type: String, trim: true, required: true, maxlength: 120 },
  floorOrRoom: { type: String, trim: true, required: true, maxlength: 80 },
  streetArea: { type: String, trim: true, required: true, maxlength: 200 },
  city: { type: String, trim: true, required: true, maxlength: 80 },
  pincode: { type: String, required: true, match: /^\d{6}$/ },
  isDefault: { type: Boolean, default: false },
});

const customerSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, minlength: 2, maxlength: 80 },
  mobile: { type: String, required: true, unique: true, trim: true, match: /^[6-9]\d{9}$/, index: true },
  email: {
    type: String,
    trim: true,
    lowercase: true,
    maxlength: 120,
    match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    default: undefined,
    unique: true,
    sparse: true,
  },
  savedAddresses: { type: [savedAddressSchema], default: [] },
  savedCanteens: [{ type: mongoose.Schema.Types.ObjectId, ref: "Canteen" }],
  deliveryAddress: {
    buildingName: { type: String, trim: true, maxlength: 120, default: "" },
    floorOrRoom: { type: String, trim: true, maxlength: 80, default: "" },
    streetArea: { type: String, trim: true, maxlength: 200, default: "" },
    city: { type: String, trim: true, maxlength: 80, default: "" },
    pincode: { type: String, trim: true, default: "", match: [/^$|^\d{6}$/, "Invalid PIN"] },
  },
  officeId: { type: String, trim: true, uppercase: true, maxlength: 50, default: "" },
  password: { type: String, required: true, select: false, minlength: 8 },
}, { timestamps: true, versionKey: false });

customerSchema.pre("save", async function hashPassword() {
  if (this.isModified("password")) this.password = await bcrypt.hash(this.password, 12);
});
customerSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

module.exports = mongoose.model("Customer", customerSchema);
