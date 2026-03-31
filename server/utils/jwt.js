const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const SECRET = process.env.JWT_SECRET || 'remoteapp_dev_secret_change_in_production';
const EXPIRES_IN = '7d';

function generateToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN });
}

function verifyToken(token) {
  try {
    return jwt.verify(token, SECRET);
  } catch {
    return null;
  }
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function getExpiryDate() {
  const d = new Date();
  d.setDate(d.getDate() + 7);
  return d.toISOString();
}

module.exports = { generateToken, verifyToken, hashToken, getExpiryDate };
