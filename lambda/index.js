'use strict';

const { Client } = require('pg'); // PostgreSQL client for TimescaleDB
const AWS = require('aws-sdk'); // AWS SDK for SQS

// Configuraciones de SQS
const sqs = new AWS.SQS({ region: process.env.AWS_REGION });
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;

// Umbrales para la detección de anomalías
const INACTIVITY_THRESHOLD_MINUTES = 30;

// Cliente PostgreSQL reutilizable
let client;

/**
 * Handler principal de la Lambda
 */
exports.handler = async (event) => {
    try {
        validateEnvVariables();

        const payload = parseRequestBody(event);
        validatePayload(payload);

        await connectToTimescaleDB();

        await insertActivityData(payload);

        const anomalies = detectAnomalies(payload);

        if (anomalies.length > 0) {
            await sendToSQS(anomalies);
        }

        return createResponse(200, { message: 'Data processed successfully' });

    } catch (error) {
        console.error('Error processing request:', error);
        if (error.message.startsWith('Payload validation failed')) {
            return createResponse(400, { error: error.message });
        }
        return createResponse(500, { error: 'Internal Server Error' });
    } finally {
        // No cerramos la conexión para reutilizarla en futuras invocaciones
        // await closeTimescaleDBConnection();
    }
};

/**
 * Analiza y valida el cuerpo de la solicitud
 * @param {string} body 
 * @returns {object} parsed payload
 */
function parseRequestBody(body) {
    try {
        return JSON.parse(body);
    } catch (error) {
        throw new Error('Invalid JSON payload.');
    }
}

/**
 * Valida las variables de entorno necesarias
 */
function validateEnvVariables() {
    const requiredEnvVars = ['AWS_REGION', 'DB_USER', 'DB_PASS', 'DB_HOST', 'DB_NAME', 'SQS_QUEUE_URL'];
    requiredEnvVars.forEach((envVar) => {
        if (!process.env[envVar]) {
            throw new Error(`Missing required environment variable: ${envVar}`);
        }
    });
}

/**
 * Valida el payload de entrada
 * @param {object} payload 
 */
function validatePayload(payload) {
    const errors = [];

    if (!payload.user_id) errors.push('user_id is required');
    if (!payload.timestamp) errors.push('timestamp is required');
    if (!payload.activity_type) errors.push('activity_type is required');
    if (payload.duration_seconds === undefined || isNaN(payload.duration_seconds)) errors.push('duration_seconds must be a valid number');
    if (payload.steps_count === undefined || isNaN(payload.steps_count)) errors.push('steps_count must be a valid number');
    if (!payload.location || !isValidLocation(payload.location)) {
        errors.push('location with valid latitude and longitude is required');
    }

    if (errors.length > 0) {
        throw new Error(`Payload validation failed: ${errors.join(', ')}`);
    }
}

/**
 * Valida que la ubicación tenga latitud y longitud válidas
 * @param {object} location 
 * @returns {boolean}
 */
function isValidLocation(location) {
    return (
        location &&
        typeof location.latitude === 'number' &&
        typeof location.longitude === 'number' &&
        location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180
    );
}

/**
 * Establece una conexión a TimescaleDB
 */
async function connectToTimescaleDB() {
    if (!client) {
        const DATABASE_URL = `postgresql://${process.env.DB_USER}:${process.env.DB_PASS}@${process.env.DB_HOST}/${process.env.DB_NAME}`;
        client = new Client({ connectionString: DATABASE_URL });
        await client.connect();
        console.log('Connected to TimescaleDB');
    }
}

/**
 * Inserta los datos de actividad en TimescaleDB
 * @param {object} payload 
 */
async function insertActivityData(payload) {
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
            payload.location.accuracy_meters || null
        ];

        await client.query(query, values);
        console.log('Data inserted into TimescaleDB successfully');
    } catch (error) {
        console.error('Error inserting data into TimescaleDB:', error);
        throw error;
    }
}

/**
 * Detecta anomalías en la actividad del usuario
 * @param {object} payload 
 * @returns {array} List of anomaly events
 */
function detectAnomalies(payload) {
    const anomalies = [];

    if (payload.duration_seconds > INACTIVITY_THRESHOLD_MINUTES * 60) {
        anomalies.push({
            type: 'inactivity',
            message: `User ${payload.user_id} has been inactive for ${payload.duration_seconds} seconds.`,
            timestamp: payload.timestamp
        });
    }

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
 * Envía eventos de anomalías a la cola SQS
 * @param {array} anomalies 
 */
async function sendToSQS(anomalies) {
    try {
        const messageBody = JSON.stringify(anomalies);
        const MAX_MESSAGE_SIZE = 256 * 1024; // 256 KB

        if (Buffer.byteLength(messageBody, 'utf8') > MAX_MESSAGE_SIZE) {
            // Divide las anomalías en múltiples mensajes si exceden el tamaño
            const chunks = chunkArray(anomalies, calcularChunkSize(anomalies));
            for (const chunk of chunks) {
                const message = {
                    MessageBody: JSON.stringify(chunk),
                    QueueUrl: SQS_QUEUE_URL
                };
                await sqs.sendMessage(message).promise();
            }
        } else {
            const message = {
                MessageBody: messageBody,
                QueueUrl: SQS_QUEUE_URL
            };
            await sqs.sendMessage(message).promise();
        }

        console.log('Anomaly event sent to SQS successfully');
    } catch (error) {
        console.error('Error sending anomaly event to SQS:', error);
        throw error;
    }
}

/**
 * Divide un array en chunks de tamaño especificado
 * @param {array} array 
 * @param {number} chunkSize 
 * @returns {array}
 */
function chunkArray(array, chunkSize) {
    const chunks = [];
    for (let i = 0; i < array.length; i += chunkSize) {
        chunks.push(array.slice(i, i + chunkSize));
    }
    return chunks;
}

/**
 * Calcula el tamaño del chunk basado en el tamaño total y el máximo permitido
 * @param {array} anomalies 
 * @returns {number}
 */
function calcularChunkSize(anomalies) {
    // Implementa una lógica adecuada para dividir las anomalías
    // Por ejemplo, dividir en 10 partes
    return Math.ceil(anomalies.length / 10);
}

/**
 * Crea una respuesta HTTP
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
