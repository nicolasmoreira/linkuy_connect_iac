"use strict";

const { Pool } = require("pg");
const AWS = require("aws-sdk");

// Define event type constants
const EVENT_TYPES = {
  FALL_DETECTED: "FALL_DETECTED",
  INACTIVITY_ALERT: "INACTIVITY_ALERT",
  LOCATION_UPDATE: "LOCATION_UPDATE",
  EMERGENCY_BUTTON_PRESSED: "EMERGENCY_BUTTON_PRESSED",
};

// AWS SQS Configuration
const sqs = new AWS.SQS({ region: process.env.AWS_REGION });
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;

// Database configuration with `pg.Pool`
const pool = new Pool({
  connectionString: `postgres://${process.env.DB_USERNAME}:${process.env.DB_PASSWORD}@${process.env.RDS_ENDPOINT}/${process.env.DB_NAME}`,
  ssl: { rejectUnauthorized: false },
  max: 10, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // Close idle clients after 30s
  connectionTimeoutMillis: 5000, // Connection timeout
});

/**
 * Main Lambda handler
 */
exports.handler = async (event) => {
  let client;
  try {
    const payload = JSON.parse(event.body);
    validatePayload(payload);

    client = await pool.connect(); // Get a client from the pool
    await insertActivityLogData(client, payload);

    if (
      [
        EVENT_TYPES.FALL_DETECTED,
        EVENT_TYPES.INACTIVITY_ALERT,
        EVENT_TYPES.EMERGENCY_BUTTON_PRESSED,
      ].includes(payload.type)
    ) {
      await sendToSQS(payload);
    }

    return createResponse(200, { message: "Data processed successfully" });
  } catch (error) {
    console.error("Error processing request:", error);
    return createResponse(error.statusCode || 500, {
      error: error.message || "Internal Server Error",
    });
  } finally {
    if (client) client.release(); // Release the client back to the pool
  }
};

/**
 * Validates the input payload
 */
function validatePayload(payload) {
  const requiredFields = ["user_id", "type", "location"];
  const errors = requiredFields.filter((field) => !payload[field]);

  if (!isValidLocation(payload.location)) {
    errors.push("location must have valid latitude and longitude");
  }

  if (errors.length > 0) {
    throw new Error(`Payload validation failed: ${errors.join(", ")}`);
  }
}

/**
 * Validates that location has valid latitude and longitude
 */
function isValidLocation(location) {
  return (
    location &&
    typeof location.latitude === "number" &&
    typeof location.longitude === "number" &&
    location.latitude >= -90 &&
    location.latitude <= 90 &&
    location.longitude >= -180 &&
    location.longitude <= 180
  );
}

/**
 * Inserts activity log data using `pg.Pool`
 */
async function insertActivityLogData(client, payload) {
  try {
    const query = `
      INSERT INTO activity_log (user_id, type, steps, distance_km, latitude, longitude, accuracy_meters)
      VALUES ($1, $2::VARCHAR, $3, $4, $5, $6, $7)
    `;

    const values = [
      payload.user_id,
      String(payload.type),
      payload.steps || 0,
      payload.distance_km || 0,
      payload.location.latitude || null,
      payload.location.longitude || null,
      payload.location.accuracy || null,
    ];

    await client.query(query, values);
    console.log("Data inserted");
  } catch (error) {
    console.error("Error inserting data:", error);
    throw error;
  }
}

/**
 * Sends fall or inactivity events to SQS
 */
async function sendToSQS(payload) {
  try {
    const params = {
      MessageBody: JSON.stringify(payload),
      QueueUrl: SQS_QUEUE_URL,
    };
    await sqs.sendMessage(params).promise();
    console.log(`Event sent to SQS: ${payload.type}`);
  } catch (error) {
    console.error("Error sending event to SQS:", error);
    throw error;
  }
}

/**
 * Creates an HTTP response
 */
function createResponse(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}
