// ─────────────────────────────────────────────────────────────
//  Socket Signaling — Phase 2
//  Handles: device registration, connection requests,
//           permission responses, connection state
// ─────────────────────────────────────────────────────────────

const { getDB } = require('../database/db');

// In-memory map: deviceCode -> socketId
// So we can find any online device instantly
const onlineDevices = new Map();

function registerSocketHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[Socket] Connected: ${socket.id}`);

    // ── REGISTER DEVICE ────────────────────────────────────────
    // Called when a user opens the app and is logged in
    // payload: { deviceCode, userId, fullName }
    socket.on('device:register', (data) => {
      const { deviceCode, userId, fullName } = data;

      if (!deviceCode) {
        socket.emit('error', { message: 'deviceCode is required' });
        return;
      }

      // Store socket mapping
      onlineDevices.set(deviceCode, {
        socketId: socket.id,
        userId,
        fullName,
        deviceCode,
        connectedAt: new Date().toISOString(),
      });

      // Attach deviceCode to this socket for cleanup on disconnect
      socket.deviceCode = deviceCode;

      socket.emit('device:registered', { success: true, deviceCode });
      console.log(`[Socket] Device registered: ${deviceCode} (${fullName})`);
    });

    // ── SEND CONNECTION REQUEST ────────────────────────────────
    // Initiator enters target's code and presses Connect
    // payload: { targetCode, initiatorCode, initiatorName }
    socket.on('connection:request', (data) => {
      const { targetCode, initiatorCode, initiatorName } = data;

      const target = onlineDevices.get(targetCode);

      if (!target) {
        // Target device is offline
        socket.emit('connection:target_offline', {
          targetCode,
          message: 'This device is currently offline.',
        });
        return;
      }

      // Log connection attempt in DB
      try {
        const db = getDB();
        const initiator = onlineDevices.get(initiatorCode);
        if (initiator) {
          db.prepare(`
            INSERT INTO connection_logs (initiator_id, target_code, status)
            VALUES (?, ?, 'pending')
          `).run(initiator.userId, targetCode);
        }
      } catch (err) {
        console.error('[Socket] DB log error:', err.message);
      }

      // Forward request to target device
      io.to(target.socketId).emit('connection:incoming', {
        initiatorCode,
        initiatorName,
        initiatorSocketId: socket.id,
        timestamp: new Date().toISOString(),
      });

      // Tell initiator the request was sent
      socket.emit('connection:request_sent', {
        targetCode,
        targetName: target.fullName,
      });

      console.log(`[Socket] Connection request: ${initiatorCode} -> ${targetCode}`);
    });

    // ── PERMISSION RESPONSE (from target) ─────────────────────
    // Target accepts or rejects the connection request
    // payload: { initiatorSocketId, initiatorCode, targetCode, accepted }
    socket.on('connection:respond', (data) => {
      const { initiatorSocketId, initiatorCode, targetCode, accepted } = data;

      // Update DB log
      try {
        const db = getDB();
        const status = accepted ? 'connected' : 'rejected';
        db.prepare(`
          UPDATE connection_logs
          SET status = ?, connected_at = datetime('now')
          WHERE initiator_id = (
            SELECT id FROM users WHERE device_code = ?
          ) AND target_code = ? AND status = 'pending'
        `).run(status, initiatorCode, targetCode);
      } catch (err) {
        console.error('[Socket] DB update error:', err.message);
      }

      if (accepted) {
        // Tell initiator: accepted → proceed to session
        io.to(initiatorSocketId).emit('connection:accepted', {
          targetCode,
          targetName: onlineDevices.get(targetCode)?.fullName || 'Unknown',
          targetSocketId: socket.id,
        });

        // Tell target: connection is live
        socket.emit('connection:live', {
          initiatorCode,
          initiatorSocketId,
        });

        console.log(`[Socket] Connection accepted: ${initiatorCode} <-> ${targetCode}`);
      } else {
        // Tell initiator: rejected
        io.to(initiatorSocketId).emit('connection:rejected', {
          targetCode,
          targetName: onlineDevices.get(targetCode)?.fullName || 'Unknown',
          message: 'Connection request was declined.',
        });

        console.log(`[Socket] Connection rejected: ${initiatorCode} -> ${targetCode}`);
      }
    });

    // ── CANCEL REQUEST (initiator cancels before target responds) ─
    // payload: { targetCode, initiatorCode }
    socket.on('connection:cancel', (data) => {
      const { targetCode, initiatorCode } = data;
      const target = onlineDevices.get(targetCode);

      if (target) {
        io.to(target.socketId).emit('connection:cancelled', { initiatorCode });
      }

      console.log(`[Socket] Request cancelled: ${initiatorCode} -> ${targetCode}`);
    });

    // ── CHECK IF DEVICE IS ONLINE ──────────────────────────────
    // payload: { deviceCode }
    socket.on('device:check_online', (data) => {
      const { deviceCode } = data;
      const isOnline = onlineDevices.has(deviceCode);
      socket.emit('device:online_status', { deviceCode, isOnline });
    });

    // ── DISCONNECT ─────────────────────────────────────────────
    socket.on('disconnect', () => {
      if (socket.deviceCode) {
        onlineDevices.delete(socket.deviceCode);
        console.log(`[Socket] Device offline: ${socket.deviceCode}`);
      }
      console.log(`[Socket] Disconnected: ${socket.id}`);
    });
  });
}

// Helper to check if a device is online (used by REST routes)
function isDeviceOnline(deviceCode) {
  return onlineDevices.has(deviceCode);
}

module.exports = { registerSocketHandlers, isDeviceOnline };
