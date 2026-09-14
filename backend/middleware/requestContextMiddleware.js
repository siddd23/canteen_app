const crypto = require("crypto");

const requestContext = (req, res, next) => {
  const suppliedRequestId = req.get("x-request-id");
  req.requestId =
    suppliedRequestId && suppliedRequestId.length <= 100
      ? suppliedRequestId
      : crypto.randomUUID();

  req.requestStartedAt = Date.now();
  res.setHeader("x-request-id", req.requestId);
  next();
};

module.exports = requestContext;
