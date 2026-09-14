require("dotenv").config();

const app = require("./app");
const connectDatabase = require("./config/database");
const mongoose = require("mongoose");
const { validateEnvironment } = require("./config/environment");
const http = require("http");
const { initializeRealtime } = require("./services/realtimeService");

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    validateEnvironment();
    await connectDatabase();

    const server = http.createServer(app);
    initializeRealtime(server);
    server.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on http://localhost:${PORT}`);
    });

    server.requestTimeout = 30000;
    server.headersTimeout = 35000;
    server.keepAliveTimeout = 5000;

    let shuttingDown = false;
    const shutdown = async (signal, exitCode = 0) => {
      if (shuttingDown) return;
      shuttingDown = true;
      console.log(`${signal} received. Closing server safely...`);

      const forceExit = setTimeout(() => {
        console.error("Graceful shutdown timed out");
        process.exit(1);
      }, 10000);
      forceExit.unref();

      server.close(async () => {
        try {
          await mongoose.disconnect();
          clearTimeout(forceExit);
          console.log("Server and database connections closed");
          process.exit(exitCode);
        } catch (error) {
          console.error(`Shutdown failed: ${error.message}`);
          process.exit(1);
        }
      });
    };

    process.on("SIGTERM", () => shutdown("SIGTERM"));
    process.on("SIGINT", () => shutdown("SIGINT"));
    process.on("unhandledRejection", (error) => {
      console.error("Unhandled rejection", error);
      shutdown("unhandledRejection", 1);
    });
    process.on("uncaughtException", (error) => {
      console.error("Uncaught exception", error);
      shutdown("uncaughtException", 1);
    });
  } catch (error) {
    console.error(`Server startup failed: ${error.message}`);
    process.exit(1);
  }
};

startServer();
