const tasks = require("./routes/tasks");
const connection = require("./db");
const cors = require("cors");
const express = require("express");
const mongoose = require("mongoose");
const { metricsMiddleware, startMetricsServer } = require("./metrics");

const app = express();

connection();

app.use(express.json());
app.use(metricsMiddleware);

// Restrict CORS to frontend domain only (sec-cors) — never use "*"
const allowedOrigin = process.env.ALLOWED_ORIGIN || "https://devops.example.com";
app.use(
  cors({
    origin: function (origin, callback) {
      // Allow same-origin / non-browser (no Origin header) and the configured frontend
      if (!origin || origin === allowedOrigin) {
        return callback(null, true);
      }
      return callback(new Error(`CORS blocked for origin: ${origin}`));
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    credentials: true,
  })
);

app.get("/healthz", (req, res) => {
  res.status(200).send("Healthy");
});

let lastReadyState = null;
app.get("/ready", (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;
  if (isDbConnected !== lastReadyState) {
    console.log(`Database readyState: ${mongoose.connection.readyState}`);
    lastReadyState = isDbConnected;
  }
  if (isDbConnected) {
    res.status(200).send("Ready");
  } else {
    res.status(503).send("Not Ready");
  }
});

app.get("/started", (req, res) => {
  res.status(200).send("Started");
});

app.use("/api/tasks", tasks);

const port = process.env.PORT || 3500;
const metricsPort = Number(process.env.METRICS_PORT || 9090);

startMetricsServer(metricsPort);
app.listen(port, () => console.log(`Listening on port ${port}...`));
