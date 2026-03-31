const { verifyToken, hashToken } = require('../utils/jwt');
const { getDB } = require('../database/db');

function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];
  const decoded = verifyToken(token);

  if (!decoded) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }

  // Check if session is still active in DB
  const db = getDB();
  const tokenHash = hashToken(token);
  const session = db.prepare(`
    SELECT s.*, u.is_active FROM sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_hash = ? AND s.is_active = 1
  `).get(tokenHash);

  if (!session) {
    return res.status(401).json({ success: false, message: 'Session expired or revoked' });
  }

  if (!session.is_active) {
    return res.status(403).json({ success: false, message: 'Account deactivated' });
  }

  req.user = decoded;
  req.sessionTokenHash = tokenHash;
  next();
}

module.exports = authMiddleware;
