const jwt = require("jsonwebtoken");
const Customer = require("../models/Customer");

const readCustomer = async (req, required) => {
  const header = req.headers.authorization || "";
  if (!header.startsWith("Bearer ")) {
    if (required) return { error: "Customer authentication is required" };
    return {};
  }
  try {
    const decoded = jwt.verify(header.slice(7), process.env.JWT_SECRET, {
      issuer: "canteen-app",
      audience: "bookfood-customers",
    });
    if (decoded.role !== "customer") return { error: "Invalid customer token" };
    const customer = await Customer.findById(decoded.id);
    if (!customer) return { error: "Customer account no longer exists" };
    return { customer };
  } catch (_) {
    return { error: "Customer session is invalid or expired" };
  }
};

const customerProtect = async (req, res, next) => {
  const result = await readCustomer(req, true);
  if (result.error) return res.status(401).json({ success: false, message: result.error });
  req.customer = result.customer;
  next();
};

const optionalCustomer = async (req, res, next) => {
  const result = await readCustomer(req, false);
  if (result.error) return res.status(401).json({ success: false, message: result.error });
  req.customer = result.customer || null;
  next();
};

module.exports = { customerProtect, optionalCustomer };
