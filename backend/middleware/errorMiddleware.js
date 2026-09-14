const notFound = (req, res, next) => {
  const error = new Error(
    `Route not found: ${req.method} ${req.originalUrl}`
  );

  res.status(404);
  next(error);
};

const errorHandler = (error, req, res, next) => {
  let statusCode =
    error.statusCode || (res.statusCode && res.statusCode !== 200
      ? res.statusCode
      : 500);

  let message = error.message || "Internal server error";

  if (error.name === "CastError" && error.kind === "ObjectId") {
    statusCode = 400;
    message = "Invalid resource ID";
  }

  if (error.name === "ValidationError") {
    statusCode = 400;
    message = Object.values(error.errors)
      .map((validationError) => validationError.message)
      .join(", ");
  }

  if (error.code === 11000) {
    statusCode = 409;

    const duplicateField = Object.keys(error.keyValue || {})[0];

    message = duplicateField
      ? `${duplicateField} already exists`
      : "Duplicate value detected";
  }

  if (statusCode >= 500) {
    console.error(JSON.stringify({
      level: "error",
      message: error.message,
      requestId: req.requestId,
      method: req.method,
      path: req.originalUrl,
      stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
      timestamp: new Date().toISOString(),
    }));
  }

  res.status(statusCode).json({
    success: false,
    message,
    requestId: req.requestId,
    ...(process.env.NODE_ENV === "development" && {
      stack: error.stack,
    }),
  });
};

module.exports = {
  notFound,
  errorHandler,
};
