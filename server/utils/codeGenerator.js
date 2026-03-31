const { getDB } = require('../database/db');

/**
 * Generates a unique 12-digit numeric code for a device.
 * Format: XXXX-XXXX-XXXX (display) | 123456789012 (stored)
 * Guarantees uniqueness by checking DB before returning.
 */
function generateRawCode() {
  // Ensure first digit is never 0 (so it's always 12 digits)
  const first = Math.floor(Math.random() * 9) + 1;
  const rest = Math.floor(Math.random() * 99999999999)
    .toString()
    .padStart(11, '0');
  return `${first}${rest}`;
}

function formatCode(raw) {
  // Display format: 1234-5678-9012
  return `${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8, 12)}`;
}

async function generateUniqueDeviceCode() {
  const db = getDB();
  const stmt = db.prepare('SELECT id FROM users WHERE device_code = ?');

  let attempts = 0;
  while (attempts < 10) {
    const code = generateRawCode();
    const existing = stmt.get(code);
    if (!existing) {
      return code; // Unique — safe to use
    }
    attempts++;
  }

  throw new Error('Failed to generate unique device code after 10 attempts');
}

module.exports = { generateUniqueDeviceCode, formatCode };
