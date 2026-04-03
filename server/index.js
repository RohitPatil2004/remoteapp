const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const authRoutes   = require('./routes/auth');
const deviceRoutes = require('./routes/device');
const { initDB }   = require('./database/db');
const { registerSocketHandlers } = require('./socket/signaling');

const app    = express();
const server = http.createServer(app);
const io     = socketIO(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// REST Routes
app.use('/api/auth',   authRoutes);
app.use('/api/device', deviceRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'RemoteApp Server Running', version: '2.0.0' });
});

// Socket.IO Phase 2 signaling
registerSocketHandlers(io);

// Initialize DB then start server
const PORT = process.env.PORT || 5000;
initDB().then(() => {
  server.listen(PORT, () => {
    console.log(`\n✅ RemoteApp Server running on http://localhost:${PORT}`);
    console.log(`📦 Database initialized`);
    console.log(`🔌 Socket.IO signaling ready`);
    console.log(`🚀 Phase 2 active\n`);
  });
}).catch((err) => {
  console.error('❌ Failed to initialize database:', err);
  process.exit(1);
});

module.exports = { io };
