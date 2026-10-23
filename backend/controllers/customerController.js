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

const profile = (req, res) => res.json({ success: true, data: { customer: publicCustomer(req.customer) } });

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

const orders = async (req, res, next) => {
  try {
    const list = await Order.find({ customerId: req.customer._id })
      .select("orderNumber orderSource officeSnapshot deliveryAddress canteenSnapshot items itemCount grandTotal estimatedPreparationTime orderStatus paymentStatus fulfillmentType scheduledFor scheduledSlot createdAt updatedAt")
      .sort({ createdAt: -1 }).limit(100).lean();
    return res.json({ success: true, data: { orders: list } });
  } catch (error) { next(error); }
};

module.exports = { signup, login, profile, updateProfile, orders };
