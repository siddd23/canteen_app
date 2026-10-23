const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");

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
