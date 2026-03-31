const express = require('express');
const router = express.Router();

const { getDB } = require('../database/db');
const authMiddleware = require('../middleware/auth');

// ─── LOOKUP DEVICE BY CODE ────────────────────────────────────────────────────
// Used when you want to connect to another device
router.get('/lookup/:code', authMiddleware, (req, res) => {
  try {
    const rawCode = req.params.code.replace(/-/g, ''); // Remove dashes if formatted

    if (rawCode.length !== 12 || !/^\d{12}$/.test(rawCode)) {
      return res.status(400).json({ success: false, message: 'Invalid device code format' });
    }

    const db = getDB();
    const device = db.prepare(`
      SELECT id, full_name, device_code FROM users
      WHERE device_code = ? AND is_active = 1
    `).get(rawCode);

    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not found or inactive' });
    }

    // Don't allow connecting to yourself
    if (device.id === req.user.id) {
      return res.status(400).json({ success: false, message: 'Cannot connect to your own device' });
    }

    return res.json({
      success: true,
      data: {
        device_code: device.device_code,
        device_code_display: `${device.device_code.slice(0,4)}-${device.device_code.slice(4,8)}-${device.device_code.slice(8,12)}`,
        owner_name: device.full_name
      }
    });

  } catch (err) {
    console.error('[Device Lookup Error]', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ─── GET MY DEVICE INFO ───────────────────────────────────────────────────────
router.get('/my-device', authMiddleware, (req, res) => {
  try {
    const db = getDB();
    const user = db.prepare(`
      SELECT device_code, full_name, created_at FROM users WHERE id = ?
    `).get(req.user.id);

    return res.json({
      success: true,
      data: {
        device_code: user.device_code,
        device_code_display: `${user.device_code.slice(0,4)}-${user.device_code.slice(4,8)}-${user.device_code.slice(8,12)}`,
        owner_name: user.full_name
      }
    });
  } catch (err) {
    console.error('[My Device Error]', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
