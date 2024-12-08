'use strict';

const { Client } = require('pg'); // PostgreSQL client for TimescaleDB
const AWS = require('aws-sdk'); // AWS SDK for SQS
const crypto = require('crypto'); // For simple security measures like generating hashes

// SQS and RDS configurations are loaded from environment variables
const sqs = new AWS.SQS({ region: process.env.AWS_REGION });
const DATABASE_URL = process.env.DATABASE_URL;
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;

// Thresholds for anomaly detection
const INACTIVITY_THRESHOLD_MINUTES = 30; // Example threshold for inactivity
const FALL_DETECTION_THRESHOLD_G = 2.5; // Example threshold for fall detection (G-force)

exports.handler = async (event) => {
    try {
        // Parse the incoming request body
        const payload = JSON.parse(event.body);
        
        // Validate the API Key (if required)
        if (!isValidApiKey(event.headers['x-api-key'])) {
            return createResponse(403, { error: 'Invalid API Key' });
        }

        // Validate and sanitize the payload
        const validationErrors = validatePayload(payload);
        if (validationErrors.length > 0) {
            return createResponse(400, { errors: validationErrors });
        }

        // Insert the activity data into TimescaleDB
        await insertIntoTimescaleDB(payload);

        // Check for inactivity or anomaly detection logic
        const anomalies = detectAnomalies(payload);
        
        // If anomalies are detected, send them to SQS
        if (anomalies.length > 0) {
            await sendToSQS(anomalies);
        }

        return createResponse(200, { message: 'Data processed successfully' });

    } catch (error) {
        console.error('Error processing request:', error);
        return createResponse(500, { error: 'Internal Server Error' });
    }
};

/**
 * Validate the API key (optional, can be configured if needed).
 * @param {string} apiKey 
 * @returns {boolean}
 */
function isValidApiKey(apiKey) {
    // You can extend this logic to fetch API keys from a database or cache
    const validApiKeys = process.env.VALID_API_KEYS.split(',');
    return validApiKeys.includes(apiKey);
}

/**
 * Validates the incoming payload to ensure required fields are present.
 * @param {object} payload 
 * @returns {array} An array of validation error messages.
 */
function validatePayload(payload) {
    const errors = [];
    if (!payload.user_id) errors.push('user_id is required');
    if (!payload.timestamp) errors.push('timestamp is required');
    if (!payload.activity_type) errors.push('activity_type is required');
    if (!payload.duration_seconds || isNaN(payload.duration_seconds)) errors.push('duration_seconds must be a valid number');
    if (!payload.steps_count || isNaN(payload.steps_count)) errors.push('steps_count must be a valid number');
    if (!payload.location || !payload.location.latitude || !payload.location.longitude) {
        errors.push('location with latitude and longitude is required');
    }
    return errors;
}

/**
 * Inserts the activity data into TimescaleDB.
 * @param {object} payload 
 */
async function insertIntoTimescaleDB(payload) {
    const client = new Client({ connectionString: DATABASE_URL });
    await client.connect();
    
    try {
        const query = `
            INSERT INTO activity (
                user_id, timestamp, activity_type, duration_seconds, steps_count, latitude, longitude, accuracy_meters
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `;

        const values = [
            payload.user_id,
            payload.timestamp,
            payload.activity_type,
            payload.duration_seconds,
            payload.steps_count,
            payload.location.latitude,
            payload.location.longitude,
            payload.location.accuracy_meters
        ];

        await client.query(query, values);
        console.log('Data inserted into TimescaleDB successfully');
    } catch (error) {
        console.error('Error inserting data into TimescaleDB:', error);
        throw error;
    } finally {
        await client.end();
    }
}

/**
 * Detects anomalies in the user's activity.
 * Examples:
 * - Prolonged inactivity
 * - Fall detection based on location data (if available)
 * 
 * @param {object} payload 
 * @returns {array} List of anomaly events
 */
function detectAnomalies(payload) {
    const anomalies = [];

    // Detect inactivity anomaly
    if (payload.duration_seconds > INACTIVITY_THRESHOLD_MINUTES * 60) {
        anomalies.push({
            type: 'inactivity',
            message: `User ${payload.user_id} has been inactive for ${payload.duration_seconds} seconds.`,
            timestamp: payload.timestamp
        });
    }

    // Detect fall anomaly (just an example, G-force sensor data would be required)
    if (payload.activity_type === 'fall') {
        anomalies.push({
            type: 'fall',
            message: `Fall detected for user ${payload.user_id} at location (${payload.location.latitude}, ${payload.location.longitude}).`,
            timestamp: payload.timestamp
        });
    }

    return anomalies;
}

/**
 * Sends anomaly events to the SQS queue for further processing.
 * @param {array} anomalies 
 */
async function sendToSQS(anomalies) {
    try {
        const message = {
            MessageBody: JSON.stringify(anomalies),
            QueueUrl: SQS_QUEUE_URL
        };

        await sqs.sendMessage(message).promise();
        console.log('Anomaly event sent to SQS successfully');
    } catch (error) {
        console.error('Error sending anomaly event to SQS:', error);
        throw error;
    }
}

/**
 * Creates an HTTP response.
 * @param {number} statusCode 
 * @param {object} body 
 * @returns {object} HTTP response
 */
function createResponse(statusCode, body) {
    return {
        statusCode: statusCode,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
    };
}
