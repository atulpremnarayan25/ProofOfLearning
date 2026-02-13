// ──────────────────────────────────────────────
// sockets/classroomSocket.js — Socket.IO handler
// ──────────────────────────────────────────────
const { socketAuthMiddleware } = require('../middlewares/auth');
const { EngagementEngine } = require('../services/engagementEngine');
const { QuestionEngine } = require('../services/questionEngine');
const db = require('../db');
const { v4: uuidv4 } = require('uuid');

// Active rooms: Map<classId, Set<socketId>>
const rooms = new Map();
// Map socketId → { userId, userName, classId, role }
const socketUsers = new Map();

function setupClassroomSocket(io) {
    // Authenticate every socket connection
    io.use(socketAuthMiddleware);

    // Initialize engines
    const engagementEngine = new EngagementEngine(io);
    const questionEngine = new QuestionEngine(io);

    io.on('connection', (socket) => {
        console.log(`🔌 Connected: ${socket.user.name} (${socket.user.role})`);

        // ── Join room ──────────────────────────────
        socket.on('join-room', ({ classId }) => {
            socket.join(classId);

            // Track socket ↔ user mapping
            socketUsers.set(socket.id, {
                userId: socket.user.id,
                userName: socket.user.name,
                classId,
                role: socket.user.role,
            });

            if (!rooms.has(classId)) {
                rooms.set(classId, new Set());
            }
            rooms.get(classId).add(socket.id);

            // Notify others
            socket.to(classId).emit('user-joined', {
                userId: socket.user.id,
                name: socket.user.name,
                role: socket.user.role,
            });

            // Send current participants list
            const participants = [];
            for (const sid of rooms.get(classId)) {
                const u = socketUsers.get(sid);
                if (u) participants.push({ userId: u.userId, name: u.userName, role: u.role });
            }
            socket.emit('participants-list', participants);

            // If teacher joins, start engagement engine
            if (socket.user.role === 'teacher') {
                engagementEngine.startForClass(classId);
            }

            console.log(`📚 ${socket.user.name} joined room ${classId}`);
        });

        // ── Leave room ─────────────────────────────
        socket.on('leave-room', ({ classId }) => {
            handleLeave(socket, classId, io, engagementEngine);
        });

        // ── Chat message ───────────────────────────
        socket.on('chat-message', ({ classId, message }) => {
            io.to(classId).emit('chat-message', {
                userId: socket.user.id,
                name: socket.user.name,
                message,
                timestamp: new Date().toISOString(),
            });
        });

        // ── Raise hand ─────────────────────────────
        socket.on('raise-hand', ({ classId }) => {
            io.to(classId).emit('hand-raised', {
                userId: socket.user.id,
                name: socket.user.name,
            });
        });

        // ── WebRTC signaling ───────────────────────
        socket.on('webrtc-offer', ({ classId, targetUserId, offer }) => {
            // Find the target socket
            const targetSid = findSocketByUserId(classId, targetUserId);
            if (targetSid) {
                io.to(targetSid).emit('webrtc-offer', {
                    fromUserId: socket.user.id,
                    offer,
                });
            }
        });

        socket.on('webrtc-answer', ({ classId, targetUserId, answer }) => {
            const targetSid = findSocketByUserId(classId, targetUserId);
            if (targetSid) {
                io.to(targetSid).emit('webrtc-answer', {
                    fromUserId: socket.user.id,
                    answer,
                });
            }
        });

        socket.on('webrtc-ice-candidate', ({ classId, targetUserId, candidate }) => {
            const targetSid = findSocketByUserId(classId, targetUserId);
            if (targetSid) {
                io.to(targetSid).emit('webrtc-ice-candidate', {
                    fromUserId: socket.user.id,
                    candidate,
                });
            }
        });

        // ── Engagement popup response ──────────────
        socket.on('popup-response', ({ classId, popupId }) => {
            engagementEngine.handleResponse(classId, socket.user.id, popupId);
        });

        // ── Teacher triggers question ──────────────
        socket.on('trigger-question', ({ classId, questionId }) => {
            if (socket.user.role === 'teacher') {
                questionEngine.broadcastQuestion(classId, questionId);
            }
        });

        // ── Student submits answer ─────────────────
        socket.on('submit-answer', ({ classId, questionId, optionId, timeTaken }) => {
            questionEngine.handleAnswer(socket.user.id, questionId, optionId, timeTaken);
        });

        // ── Focus tracking ─────────────────────────
        socket.on('focus-event', ({ classId, eventType, duration }) => {
            const id = uuidv4();
            db.prepare(
                'INSERT INTO focus_logs (id, student_id, class_id, duration, event_type) VALUES (?, ?, ?, ?, ?)'
            ).run(id, socket.user.id, classId, duration || 0, eventType);
        });

        // ── Disconnect ─────────────────────────────
        socket.on('disconnect', () => {
            const userData = socketUsers.get(socket.id);
            if (userData) {
                handleLeave(socket, userData.classId, io, engagementEngine);
            }
            console.log(`🔌 Disconnected: ${socket.user.name}`);
        });
    });
}

function handleLeave(socket, classId, io, engagementEngine) {
    socket.leave(classId);
    socketUsers.delete(socket.id);

    if (rooms.has(classId)) {
        rooms.get(classId).delete(socket.id);
        if (rooms.get(classId).size === 0) {
            rooms.delete(classId);
            engagementEngine.stopForClass(classId);
        }
    }

    io.to(classId).emit('user-left', {
        userId: socket.user.id,
        name: socket.user.name,
    });
}

function findSocketByUserId(classId, userId) {
    if (!rooms.has(classId)) return null;
    for (const sid of rooms.get(classId)) {
        const u = socketUsers.get(sid);
        if (u && u.userId === userId) return sid;
    }
    return null;
}

module.exports = { setupClassroomSocket };
