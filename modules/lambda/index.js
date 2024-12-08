const { Client } = require('pg'); // PostgreSQL client for TimescaleDB
const AWS = require('aws-sdk'); // AWS SDK to interact with SQS and other AWS services
const crypto = require('crypto'); // Used for input sanitization

// Environment variables (configured via AWS Lambda environment variables)
const DB_CONFIG = {
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
    ssl: { rejectUnauthorized: true } // Enforce SSL for secure connections
};

const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;
const sqs = new AWS.SQS({ apiVersion: '2012-11-05' });

let dbClient; // To cache the DB client connection

// Function to establish and cache a connection to the TimescaleDB
async function connectToDatabase() {
    if (!dbClient) {
        dbClient = new Client(DB_CONFIG);
        await dbClient.connect();
    }
    return dbClient;
}

// Function to validate the structure of the incoming payload
function validatePayload(payload) {
    const requiredFields = ['user_id', 'timestamp', 'activity_type', 'duration_seconds', 'steps_count', 'location'];
    requiredFields.forEach(field => {
        if (!payload.hasOwnProperty(field)) {
            throw new Error(`Missing required field: ${field}`);
        }
    });
}

// Function to sanitize input to avoid SQL injection and other types of attacks
function sanitizeInput(input) {
    return input.replace(/[^a-zA-Z0-9-_]/g, ''); // Allow only alphanumeric, dash, and underscore characters
}

// Function to check for anomalies, such as inactivity or unexpected activity
async function checkForAnomalies(client, payload) {
    const userId = sanitizeInput(payload.user_id);
    const query = `
        SELECT timestamp 
        FROM activity_logs 
        WHERE user_id = $1 
        ORDER BY timestamp DESC 
        LIMIT 1
    `;
    const result = await client.query(query, [userId]);

    if (result.rows.length === 0) {
        console.log(`No previous activity found for user_id: ${userId}`);
        return;
    }

    const lastActivityTime = new Date(result.rows[0].timestamp);
    const currentActivityTime = new Date(payload.timestamp);
    const timeDifferenceMinutes = (currentActivityTime - lastActivityTime) / (1000 * 60); // Time difference in minutes

    // **Anomaly 1: Inactivity Detection**
    const INACTIVITY_THRESHOLD_MINUTES = 30; // Set the inactivity threshold (can be customized)
    if (timeDifferenceMinutes >= INACTIVITY_THRESHOLD_MINUTES) {
        console.log(`Inactivity alert for user ${userId}, no activity for ${timeDifferenceMinutes} minutes`);
        await sendToSQS('inactivity_alert', { 
            user_id: userId, 
            last_activity_time: lastActivityTime, 
            inactivity_duration: timeDifferenceMinutes 
        });
    }

    // **Anomaly 2: Fall Detection**
    // Here you could add logic to detect a fall using the `activity_type` or `location` data
    if (payload.activity_type === 'fall') {
        console.log(`Fall detected for user ${userId}`);
        await sendToSQS('fall_alert', { 
            user_id: userId, 
            timestamp: payload.timestamp 
        });
    }

    // **Anomaly 3: Abnormal Step Count**
    const MAX_STEP_COUNT = 1000; // Set a maximum expected step count
    if (payload.steps_count > MAX_STEP_COUNT) {
        console.log(`Abnormal step count detected for user ${userId}`);
        await sendToSQS('abnormal_activity_alert', { 
            user_id: userId, 
            timestamp: payload.timestamp, 
            steps_count: payload.steps_count 
        });
    }
}

// Function to send an event to SQS
async function sendToSQS(type, message) {
    const params = {
        MessageBody: JSON.stringify({
            type: type,
            message: message,
        }),
        QueueUrl: SQS_QUEUE_URL
    };

    try {
        const result = await sqs.sendMessage(params).promise();
        console.log('Successfully sent message to SQS:', result);
    } catch (error) {
        console.error('Error sending message to SQS:', error);
    }
}

exports.handler = async (event) => {
    try {
        console.log('Received event:', JSON.stringify(event, null, 2));

        if (!event.body) {
            throw new Error('Missing request body');
        }

        const payload = JSON.parse(event.body);
        validatePayload(payload);

        const client = await connectToDatabase();

        await checkForAnomalies(client, payload);

        const query = `
            INSERT INTO activity_logs 
            (user_id, activity_type, timestamp, duration_seconds, steps_count, latitude, longitude, accuracy_meters) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `;

        const values = [
            sanitizeInput(payload.user_id), 
            sanitizeInput(payload.activity_type), 
            sanitizeInput(payload.timestamp), 
            parseInt(payload.duration_seconds, 10), 
            parseInt(payload.steps_count, 10), 
            parseFloat(payload.location.latitude), 
            parseFloat(payload.location.longitude), 
            parseFloat(payload.location.accuracy_meters)
        ];

        await client.query(query, values);

        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Activity logged successfully' }),
        };

    } catch (error) {
        console.error('Error processing request:', error);
        return {
            statusCode: 400,
            body: JSON.stringify({ error: error.message }),
        };
    }
};
