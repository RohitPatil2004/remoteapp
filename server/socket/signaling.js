const { getDB } = require('../database/db');

const onlineDevices = new Map(); // deviceCode -> { socketId, userId, fullName, deviceCode }

function registerSocketHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[Socket] Connected: ${socket.id}`);

    // ── REGISTER DEVICE ──────────────────────────────────────
    socket.on('device:register', (data) => {
      const { deviceCode, userId, fullName } = data;
      if (!deviceCode) return;
      onlineDevices.set(deviceCode, { socketId: socket.id, userId, fullName, deviceCode });
      socket.deviceCode = deviceCode;
      socket.emit('device:registered', { success: true, deviceCode });
      console.log(`[Socket] Registered: ${deviceCode} (${fullName})`);
    });

    // ── CONNECTION REQUEST ────────────────────────────────────
    socket.on('connection:request', (data) => {
      const { targetCode, initiatorCode, initiatorName } = data;
      const target = onlineDevices.get(targetCode);
      if (!target) {
        socket.emit('connection:target_offline', { targetCode, message: 'Device is offline.' });
        return;
      }
      try {
        const db = getDB();
        const initiator = onlineDevices.get(initiatorCode);
        if (initiator) {
          db.prepare(`INSERT INTO connection_logs (initiator_id, target_code, status) VALUES (?, ?, 'pending')`)
            .run(initiator.userId, targetCode);
        }
      } catch (err) { console.error('[DB] log error:', err.message); }

      io.to(target.socketId).emit('connection:incoming', {
        initiatorCode,
        initiatorName,
        initiatorSocketId: socket.id,
        timestamp: new Date().toISOString(),
      });
      socket.emit('connection:request_sent', { targetCode, targetName: target.fullName });
      console.log(`[Socket] Request: ${initiatorCode} -> ${targetCode}`);
    });

    // ── CONNECTION RESPONSE ───────────────────────────────────
    socket.on('connection:respond', (data) => {
      const { initiatorSocketId, initiatorCode, targetCode, accepted } = data;
      try {
        const db = getDB();
        db.prepare(`
          UPDATE connection_logs SET status = ?, connected_at = datetime('now')
          WHERE initiator_id = (SELECT id FROM users WHERE device_code = ?)
          AND target_code = ? AND status = 'pending'
        `).run(accepted ? 'connected' : 'rejected', initiatorCode, targetCode);
      } catch (err) { console.error('[DB] update error:', err.message); }

      if (accepted) {
        io.to(initiatorSocketId).emit('connection:accepted', {
          targetCode,
          targetName: onlineDevices.get(targetCode)?.fullName || 'Unknown',
          targetSocketId: socket.id,
        });
        socket.emit('connection:live', { initiatorCode, initiatorSocketId });
        console.log(`[Socket] Accepted: ${initiatorCode} <-> ${targetCode}`);
      } else {
        io.to(initiatorSocketId).emit('connection:rejected', {
          targetCode,
          targetName: onlineDevices.get(targetCode)?.fullName || 'Unknown',
          message: 'Connection request was declined.',
        });
        console.log(`[Socket] Rejected: ${initiatorCode} -> ${targetCode}`);
      }
    });

    // ── CANCEL REQUEST ────────────────────────────────────────
    socket.on('connection:cancel', (data) => {
      const target = onlineDevices.get(data.targetCode);
      if (target) io.to(target.socketId).emit('connection:cancelled', { initiatorCode: data.initiatorCode });
    });

    // ── CHECK ONLINE STATUS ───────────────────────────────────
    socket.on('device:check_online', (data) => {
      socket.emit('device:online_status', {
        deviceCode: data.deviceCode,
        isOnline: onlineDevices.has(data.deviceCode),
      });
    });

    // ── WEBRTC SIGNALING (relay only — server never reads content) ─
    // Offer
    socket.on('webrtc:offer', (data) => {
      const { targetSocketId, offer } = data;
      io.to(targetSocketId).emit('webrtc:offer', { offer, fromSocketId: socket.id });
      console.log(`[WebRTC] Offer relayed -> ${targetSocketId}`);
    });

    // Answer
    socket.on('webrtc:answer', (data) => {
      const { targetSocketId, answer } = data;
      io.to(targetSocketId).emit('webrtc:answer', { answer, fromSocketId: socket.id });
      console.log(`[WebRTC] Answer relayed -> ${targetSocketId}`);
    });

    // ICE Candidate
    socket.on('webrtc:candidate', (data) => {
      const { targetSocketId, candidate } = data;
      io.to(targetSocketId).emit('webrtc:candidate', { candidate, fromSocketId: socket.id });
    });

    // Call request (initiator tells peer to open call screen)
    socket.on('webrtc:call_request', (data) => {
      const { targetSocketId, callerName, callerCode } = data;
      io.to(targetSocketId).emit('webrtc:incoming_call', {
        callerName,
        callerCode,
        callerSocketId: socket.id,
      });
      console.log(`[WebRTC] Call request -> ${targetSocketId}`);
    });

    // Call accepted
    socket.on('webrtc:call_accepted', (data) => {
      io.to(data.targetSocketId).emit('webrtc:call_accepted', { fromSocketId: socket.id });
    });

    // Call rejected
    socket.on('webrtc:call_rejected', (data) => {
      io.to(data.targetSocketId).emit('webrtc:call_rejected', { fromSocketId: socket.id });
    });

    // Call ended
    socket.on('webrtc:call_ended', (data) => {
      const { targetSocketId } = data;
      if (targetSocketId) io.to(targetSocketId).emit('webrtc:call_ended', {});
      console.log(`[WebRTC] Call ended`);
    });

    // ── DISCONNECT ────────────────────────────────────────────
    socket.on('disconnect', () => {
      if (socket.deviceCode) {
        onlineDevices.delete(socket.deviceCode);
        console.log(`[Socket] Offline: ${socket.deviceCode}`);
      }
    });
  });
}

function isDeviceOnline(deviceCode) {
  return onlineDevices.has(deviceCode);
}

module.exports = { registerSocketHandlers, isDeviceOnline };
