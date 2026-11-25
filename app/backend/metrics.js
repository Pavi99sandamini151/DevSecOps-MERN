const client = require("prom-client");
const http = require("http");
const express = require("express");
const mongoose = require("mongoose");

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

const httpRequestDurationSeconds = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

const mongoReady = new client.Gauge({
  name: "mongodb_ready",
  help: "1 if mongoose is connected, else 0",
  registers: [register],
});

function normalizeRoute(req) {
  if (req.route && req.baseUrl !== undefined) {
    return `${req.baseUrl}${req.route.path}`;
  }
  if (req.path && req.path.startsWith("/api/tasks")) {
    return "/api/tasks";
  }
  return req.path || "unknown";
}

function metricsMiddleware(req, res, next) {
  if (req.path === "/metrics" || req.path === "/healthz" || req.path === "/ready" || req.path === "/started") {
    return next();
  }
  const end = httpRequestDurationSeconds.startTimer();
  res.on("finish", () => {
    const route = normalizeRoute(req);
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode),
    };
    httpRequestsTotal.inc(labels);
    end(labels);
    mongoReady.set(mongoose.connection.readyState === 1 ? 1 : 0);
  });
  next();
}

function startMetricsServer(port = 9090) {
  const metricsApp = express();
  metricsApp.get("/metrics", async (_req, res) => {
    mongoReady.set(mongoose.connection.readyState === 1 ? 1 : 0);
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  });
  http.createServer(metricsApp).listen(port, "0.0.0.0", () => {
    console.log(`Metrics listening on port ${port}...`);
  });
}

module.exports = {
  metricsMiddleware,
  startMetricsServer,
  register,
};
