// ──────────────────────────────────────────────
// routes/questions.js — Question CRUD & responses
// ──────────────────────────────────────────────
const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { authMiddleware } = require('../middlewares/auth');

const router = express.Router();
router.use(authMiddleware);

// ── POST /api/questions/create ─────────────────
// Teacher creates a question with options
router.post('/create', (req, res) => {
    try {
        if (req.user.role !== 'teacher') {
            return res.status(403).json({ error: 'Only teachers can create questions' });
        }

        const { class_id, text, options } = req.body;
        // options: [{ text: string, is_correct: boolean }]

        if (!class_id || !text || !options || options.length < 2) {
            return res.status(400).json({ error: 'class_id, text, and at least 2 options are required' });
        }

        const questionId = uuidv4();
        db.prepare('INSERT INTO questions (id, class_id, text) VALUES (?, ?, ?)')
            .run(questionId, class_id, text);

        const insertOption = db.prepare(
            'INSERT INTO options (id, question_id, text, is_correct) VALUES (?, ?, ?, ?)'
        );

        const createdOptions = options.map((opt) => {
            const optId = uuidv4();
            insertOption.run(optId, questionId, opt.text, opt.is_correct ? 1 : 0);
            return { id: optId, text: opt.text, is_correct: opt.is_correct };
        });

        res.status(201).json({
            id: questionId,
            class_id,
            text,
            options: createdOptions,
        });
    } catch (err) {
        console.error('Create question error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── POST /api/questions/respond ────────────────
// Student submits an answer
router.post('/respond', (req, res) => {
    try {
        const { question_id, option_id, time_taken } = req.body;

        if (!question_id || !option_id) {
            return res.status(400).json({ error: 'question_id and option_id are required' });
        }

        // Check if already responded
        const existing = db.prepare(
            'SELECT id FROM responses WHERE student_id = ? AND question_id = ?'
        ).get(req.user.id, question_id);

        if (existing) {
            return res.status(409).json({ error: 'Already responded to this question' });
        }

        const id = uuidv4();
        db.prepare(
            'INSERT INTO responses (id, student_id, question_id, option_id, time_taken) VALUES (?, ?, ?, ?, ?)'
        ).run(id, req.user.id, question_id, option_id, time_taken || 0);

        // Check if correct and award points
        const option = db.prepare('SELECT * FROM options WHERE id = ?').get(option_id);
        const question = db.prepare('SELECT * FROM questions WHERE id = ?').get(question_id);

        if (option && option.is_correct) {
            // Award 10 points for correct answer
            const existingPoints = db.prepare(
                'SELECT * FROM points WHERE student_id = ? AND class_id = ?'
            ).get(req.user.id, question.class_id);

            if (existingPoints) {
                db.prepare('UPDATE points SET score = score + 10 WHERE student_id = ? AND class_id = ?')
                    .run(req.user.id, question.class_id);
            } else {
                db.prepare('INSERT INTO points (id, student_id, class_id, score) VALUES (?, ?, ?, 10)')
                    .run(uuidv4(), req.user.id, question.class_id);
            }
        }

        res.json({
            correct: option ? !!option.is_correct : false,
            points_awarded: option && option.is_correct ? 10 : 0,
        });
    } catch (err) {
        console.error('Respond error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── GET /api/questions/:classId/results ────────
// Teacher gets results for all questions in a class
router.get('/:classId/results', (req, res) => {
    try {
        const questions = db.prepare(
            'SELECT * FROM questions WHERE class_id = ? ORDER BY created_at DESC'
        ).all(req.params.classId);

        const results = questions.map((q) => {
            const opts = db.prepare('SELECT * FROM options WHERE question_id = ?').all(q.id);
            const responses = db.prepare('SELECT * FROM responses WHERE question_id = ?').all(q.id);

            const totalResponses = responses.length;
            const correctResponses = responses.filter((r) => {
                const opt = opts.find((o) => o.id === r.option_id);
                return opt && opt.is_correct;
            }).length;

            return {
                ...q,
                options: opts,
                total_responses: totalResponses,
                correct_responses: correctResponses,
                correct_percentage: totalResponses > 0 ? Math.round((correctResponses / totalResponses) * 100) : 0,
            };
        });

        res.json(results);
    } catch (err) {
        console.error('Get results error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
