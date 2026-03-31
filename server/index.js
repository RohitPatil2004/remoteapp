const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const authRoutes = require('./routes/auth');
const deviceRoutes = require('./routes/device');
const { initDB } = require('./database/db');

const app = express();
const server = http.createServer(app);
const io = socketIO(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/device', deviceRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'RemoteApp Server Running', version: '1.0.0' });
});

// Socket.IO — will be expanded in Phase 2
io.on('connection', (socket) => {
  console.log(`[Socket] Client connected: ${socket.id}`);

  socket.on('disconnect', () => {
    console.log(`[Socket] Client disconnected: ${socket.id}`);
  });
});

// Initialize DB then start server
const PORT = process.env.PORT || 5000;
initDB().then(() => {
  server.listen(PORT, () => {
    console.log(`\n✅ RemoteApp Server running on http://localhost:${PORT}`);
    console.log(`📦 Database initialized`);
    console.log(`🔌 Socket.IO ready\n`);
  });
}).catch((err) => {
  console.error('❌ Failed to initialize database:', err);
  process.exit(1);
});

module.exports = { io };