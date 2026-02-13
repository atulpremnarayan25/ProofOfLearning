// ──────────────────────────────────────────────
// server.js — Express + Socket.IO entry point
// ──────────────────────────────────────────────
const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');

// Import database (auto-creates tables on first require)
require('./db');

// Routes
const authRoutes = require('./routes/auth');
const classroomRoutes = require('./routes/classroom');
const questionsRoutes = require('./routes/questions');
const analyticsRoutes = require('./routes/analytics');

// Socket handler
const { setupClassroomSocket } = require('./sockets/classroomSocket');

const app = express();
const server = http.createServer(app);

// ── Middleware ──────────────────────────────────
const FRONTEND_URL = process.env.FRONTEND_URL || '*';
app.use(cors({
    origin: FRONTEND_URL === '*' ? '*' : [FRONTEND_URL, 'http://localhost:3000'],
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

// ── API Routes ─────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/classroom', classroomRoutes);
app.use('/api/questions', questionsRoutes);
app.use('/api/analytics', analyticsRoutes);

// Health check
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Socket.IO ──────────────────────────────────
const io = new Server(server, {
    cors: {
        origin: FRONTEND_URL === '*' ? '*' : [FRONTEND_URL, 'http://localhost:3000'],
        methods: ['GET', 'POST'],
    },
});

setupClassroomSocket(io);

// ── Start Server ───────────────────────────────
const PORT = process.env.PORT || 5001;
server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/api/health`);
});
