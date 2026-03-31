const express = require('express');
const bcrypt = require('bcrypt');
const router = express.Router();

const { getDB } = require('../database/db');
const { generateUniqueDeviceCode } = require('../utils/codeGenerator');
const { generateToken, hashToken, getExpiryDate } = require('../utils/jwt');
const authMiddleware = require('../middleware/auth');

const SALT_ROUNDS = 12;

// ─── SIGNUP ───────────────────────────────────────────────────────────────────
router.post('/signup', async (req, res) => {
  const { full_name, email, password } = req.body;

  // Basic validation
  if (!full_name || !email || !password) {
    return res.status(400).json({ success: false, message: 'All fields are required' });
  }

  if (password.length < 8) {
    return res.status(400).json({ success: false, message: 'Password must be at least 8 characters' });
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ success: false, message: 'Invalid email format' });
  }

  try {
    const db = getDB();

    // Check if email already exists
    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase());
    if (existing) {
      return res.status(409).json({ success: false, message: 'Email already registered' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    // Generate unique 12-digit device code
    const deviceCode = await generateUniqueDeviceCode();

    // Insert user
    const insert = db.prepare(`
      INSERT INTO users (full_name, email, password, device_code)
      VALUES (?, ?, ?, ?)
    `);
    const result = insert.run(full_name.trim(), email.toLowerCase(), hashedPassword, deviceCode);

    // Generate JWT
    const token = generateToken({ id: result.lastInsertRowid, email: email.toLowerCase() });
    const tokenHash = hashToken(token);

    // Save session
    db.prepare(`
      INSERT INTO sessions (user_id, token_hash, device_info, ip_address, expires_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(
      result.lastInsertRowid,
      tokenHash,
      req.headers['user-agent'] || 'unknown',
      req.ip,
      getExpiryDate()
    );

    return res.status(201).json({
      success: true,
      message: 'Account created successfully',
      data: {
        token,
        user: {
          id: result.lastInsertRowid,
          full_name: full_name.trim(),
          email: email.toLowerCase(),
          device_code: deviceCode,
          // Formatted for display: XXXX-XXXX-XXXX
          device_code_display: `${deviceCode.slice(0,4)}-${deviceCode.slice(4,8)}-${deviceCode.slice(8,12)}`
        }
      }
    });

  } catch (err) {
    console.error('[Signup Error]', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ─── LOGIN ────────────────────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required' });
  }

  try {
    const db = getDB();

    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase());
    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    if (!user.is_active) {
      return res.status(403).json({ success: false, message: 'Account deactivated' });
    }

    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    // Update last login
    db.prepare('UPDATE users SET last_login = datetime("now") WHERE id = ?').run(user.id);

    // Generate JWT
    const token = generateToken({ id: user.id, email: user.email });
    const tokenHash = hashToken(token);

    // Invalidate old sessions (optional: keep only latest)
    db.prepare('UPDATE sessions SET is_active = 0 WHERE user_id = ?').run(user.id);

    // Save new session
    db.prepare(`
      INSERT INTO sessions (user_id, token_hash, device_info, ip_address, expires_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(
      user.id,
      tokenHash,
      req.headers['user-agent'] || 'unknown',
      req.ip,
      getExpiryDate()
    );

    return res.json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        user: {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          device_code: user.device_code,
          device_code_display: `${user.device_code.slice(0,4)}-${user.device_code.slice(4,8)}-${user.device_code.slice(8,12)}`
        }
      }
    });

  } catch (err) {
    console.error('[Login Error]', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ─── LOGOUT ───────────────────────────────────────────────────────────────────
router.post('/logout', authMiddleware, (req, res) => {
  try {
    const db = getDB();
    db.prepare('UPDATE sessions SET is_active = 0 WHERE token_hash = ?').run(req.sessionTokenHash);
    return res.json({ success: true, message: 'Logged out successfully' });
  } catch (err) {
    console.error('[Logout Error]', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ─── GET CURRENT USER (me) ────────────────────────────────────────────────────
router.get('/me', authMiddleware, (req, res) => {
  try {
    const db = getDB();
    const user = db.prepare('SELECT id, full_name, email, device_code, created_at, last_login FROM users WHERE id = ?').get(req.user.id);

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    return res.json({
      success: true,
      data: {
        ...user,
        device_code_display: `${user.device_code.slice(0,4)}-${user.device_code.slice(4,8)}-${user.device_code.slice(8,12)}`
      }
    });
  } catch (err) {
    console.error('[Me Error]', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
