const jwt = require("jsonwebtoken");
const Customer = require("../models/Customer");
const Order = require("../models/Order");

const tokenFor = (customer) => jwt.sign(
  { id: String(customer._id), role: "customer" },
  process.env.JWT_SECRET,
  { expiresIn: process.env.JWT_EXPIRES_IN || "7d", issuer: "canteen-app", audience: "bookfood-customers" },
);
const publicCustomer = (customer) => ({
  id: customer._id,
  name: customer.name,
  mobile: customer.mobile,
  email: customer.email || "",
  officeId: customer.officeId || "",
  deliveryAddress: customer.deliveryAddress || {},
});

const signup = async (req, res, next) => {
  try {
    const mobile = req.body.mobile.trim();
    if (await Customer.exists({ mobile })) return res.status(409).json({ success: false, message: "An account already exists for this mobile number" });
    const email = req.body.email?.trim().toLowerCase() || "";
    if (email && await Customer.exists({ email })) return res.status(409).json({ success: false, message: "An account already exists for this email address" });
    const customer = await Customer.create({
      name: req.body.name.trim(),
      mobile,
      ...(email ? { email } : {}),
      officeId: req.body.officeId?.trim().toUpperCase() || "",
      password: req.body.password,
    });
    return res.status(201).json({ success: true, data: { token: tokenFor(customer), customer: publicCustomer(customer) } });
  } catch (error) { next(error); }
};

const login = async (req, res, next) => {
  try {
    const customer = await Customer.findOne({ mobile: req.body.mobile.trim() }).select("+password");
    if (!customer || !await customer.comparePassword(req.body.password)) return res.status(401).json({ success: false, message: "Incorrect mobile number or password" });
    return res.json({ success: true, data: { token: tokenFor(customer), customer: publicCustomer(customer) } });
  } catch (error) { next(error); }
};

// Recover previous checkout addresses for accounts that ordered before
// automatic profile saving was introduced (no extra order required).
const profile = async (req, res, next) => {
  try {
    const customer = req.customer;
    const current = customer.deliveryAddress || {};
    if (!current.buildingName || !current.streetArea || !current.pincode) {
      const latest = await Order.findOne({
        customerId: customer._id,
        "deliveryAddress.buildingName": { $nin: [null, ""] },
      }).select("deliveryAddress").sort({ createdAt: -1 }).lean();
      if (latest?.deliveryAddress?.buildingName) {
        const fields = ["buildingName", "floorOrRoom", "streetArea", "city", "pincode"];
        const address = Object.fromEntries(fields.map((field) => [field, latest.deliveryAddress[field] || ""]));
        await Customer.updateOne({ _id: customer._id }, { $set: { deliveryAddress: address } });
        customer.deliveryAddress = address;
      }
    }
    return res.json({ success: true, data: { customer: publicCustomer(customer) } });
  } catch (error) { next(error); }
};

const updateProfile = async (req, res, next) => {
  try {
    const customer = await Customer.findById(req.customer._id);
    const mobile = req.body.mobile.trim();
    const email = req.body.email?.trim().toLowerCase() || "";
    const duplicate = await Customer.findOne({
      _id: { $ne: customer._id },
      $or: [
        { mobile },
        ...(email ? [{ email }] : []),
      ],
    }).select("mobile email");
    if (duplicate) {
      return res.status(409).json({
        success: false,
        message: duplicate.mobile === mobile
          ? "This mobile number is already in use"
          : "This email address is already in use",
      });
    }
    customer.name = req.body.name.trim();
    customer.mobile = mobile;
    customer.email = email || undefined;
    customer.officeId = req.body.officeId?.trim().toUpperCase() || "";
    await customer.save();
    return res.json({
      success: true,
      message: "Profile updated successfully",
      data: { customer: publicCustomer(customer) },
    });
  } catch (error) { next(error); }
};

// Update only the authenticated employee's saved checkout address.
const updateDeliveryAddress = async (req, res, next) => {
  try {
    const fields = ["buildingName", "floorOrRoom", "streetArea", "city", "pincode"];
    const address = Object.fromEntries(fields.map((field) => [field, req.body[field].trim()]));
    const customer = await Customer.findByIdAndUpdate(
      req.customer._id,
      { $set: { deliveryAddress: address } },
      { new: true, runValidators: true },
    );
    if (!customer) return res.status(404).json({ success: false, message: "Employee not found" });
    return res.json({ success: true, data: { deliveryAddress: customer.deliveryAddress } });
  } catch (error) { next(error); }
};

const orders = async (req, res, next) => {
  try {
    const list = await Order.find({ customerId: req.customer._id })
      .select("orderNumber orderSource officeSnapshot deliveryAddress canteenSnapshot items itemCount grandTotal estimatedPreparationTime orderStatus paymentStatus fulfillmentType scheduledFor scheduledSlot createdAt updatedAt")
      .sort({ createdAt: -1 }).limit(100).lean();
    return res.json({ success: true, data: { orders: list } });
  } catch (error) { next(error); }
};

module.exports = { signup, login, profile, updateProfile, updateDeliveryAddress, orders };
