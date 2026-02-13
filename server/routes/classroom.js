// ──────────────────────────────────────────────
// routes/classroom.js — Classroom CRUD & join
// ──────────────────────────────────────────────
const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { authMiddleware } = require('../middlewares/auth');

const router = express.Router();

// All classroom routes require authentication
router.use(authMiddleware);

// ── Generate a 6-char alphanumeric class code ──
function generateCode() {
    return Math.random().toString(36).substring(2, 8).toUpperCase();
}

// ── POST /api/classroom/create ─────────────────
router.post('/create', (req, res) => {
    try {
        if (req.user.role !== 'teacher') {
            return res.status(403).json({ error: 'Only teachers can create classes' });
        }

        const { title } = req.body;
        if (!title) {
            return res.status(400).json({ error: 'Class title is required' });
        }

        const id = uuidv4();
        const code = generateCode();

        db.prepare(
            'INSERT INTO classes (id, teacher_id, title, code) VALUES (?, ?, ?, ?)'
        ).run(id, req.user.id, title, code);

        res.status(201).json({ id, title, code, teacher_id: req.user.id });
    } catch (err) {
        console.error('Create class error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── POST /api/classroom/join ───────────────────
router.post('/join', (req, res) => {
    try {
        const { code } = req.body;
        if (!code) {
            return res.status(400).json({ error: 'Class code is required' });
        }

        const cls = db.prepare('SELECT * FROM classes WHERE code = ?').get(code);
        if (!cls) {
            return res.status(404).json({ error: 'Class not found' });
        }

        // Check if already enrolled
        const existing = db.prepare(
            'SELECT id FROM enrollments WHERE class_id = ? AND student_id = ?'
        ).get(cls.id, req.user.id);

        if (!existing) {
            const id = uuidv4();
            db.prepare(
                'INSERT INTO enrollments (id, class_id, student_id) VALUES (?, ?, ?)'
            ).run(id, cls.id, req.user.id);
        }

        res.json({ class_id: cls.id, title: cls.title, code: cls.code });
    } catch (err) {
        console.error('Join class error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── GET /api/classroom/list ────────────────────
router.get('/list', (req, res) => {
    try {
        let classes;
        if (req.user.role === 'teacher') {
            classes = db.prepare(
                'SELECT * FROM classes WHERE teacher_id = ? ORDER BY created_at DESC'
            ).all(req.user.id);
        } else {
            classes = db.prepare(`
        SELECT c.* FROM classes c
        JOIN enrollments e ON e.class_id = c.id
        WHERE e.student_id = ?
        ORDER BY c.created_at DESC
      `).all(req.user.id);
        }
        res.json(classes);
    } catch (err) {
        console.error('List classes error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── GET /api/classroom/:id ─────────────────────
router.get('/:id', (req, res) => {
    try {
        const cls = db.prepare('SELECT * FROM classes WHERE id = ?').get(req.params.id);
        if (!cls) {
            return res.status(404).json({ error: 'Class not found' });
        }

        const students = db.prepare(`
      SELECT u.id, u.name, u.email FROM users u
      JOIN enrollments e ON e.student_id = u.id
      WHERE e.class_id = ?
    `).all(cls.id);

        res.json({ ...cls, students });
    } catch (err) {
        console.error('Get class error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── POST /api/classroom/:id/activate ───────────
router.post('/:id/activate', (req, res) => {
    try {
        if (req.user.role !== 'teacher') {
            return res.status(403).json({ error: 'Only teachers can activate classes' });
        }
        db.prepare('UPDATE classes SET is_active = 1 WHERE id = ? AND teacher_id = ?')
            .run(req.params.id, req.user.id);
        res.json({ message: 'Class activated' });
    } catch (err) {
        console.error('Activate class error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── POST /api/classroom/:id/deactivate ─────────
router.post('/:id/deactivate', (req, res) => {
    try {
        if (req.user.role !== 'teacher') {
            return res.status(403).json({ error: 'Only teachers can deactivate classes' });
        }
        db.prepare('UPDATE classes SET is_active = 0 WHERE id = ? AND teacher_id = ?')
            .run(req.params.id, req.user.id);
        res.json({ message: 'Class deactivated' });
    } catch (err) {
        console.error('Deactivate class error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
