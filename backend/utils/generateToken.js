const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const generateToken = ({ id, role }) => {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is missing");
  }

  return jwt.sign(
    {
      id,
      role,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "7d",

      // Makes every generated token unique
      jwtid: crypto.randomUUID(),

      issuer: "canteen-app",
      audience: "canteen-app-users",
    }
  );
};

module.exports = generateToken;