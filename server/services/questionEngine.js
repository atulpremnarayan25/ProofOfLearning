// ──────────────────────────────────────────────
// services/questionEngine.js — Timed MCQ questions
// ──────────────────────────────────────────────
const { v4: uuidv4 } = require('uuid');
const db = require('../db');

class QuestionEngine {
    constructor(io) {
        this.io = io;
        // Track active question timers: Map<questionId, timeoutId>
        this.activeTimers = new Map();
    }

    /**
     * Broadcast a question to all students in a class.
     * Starts 60-second timer; after which results are compiled.
     */
    broadcastQuestion(classId, questionId) {
        const question = db.prepare('SELECT * FROM questions WHERE id = ?').get(questionId);
        if (!question) return;

        const options = db.prepare('SELECT id, text FROM options WHERE question_id = ?').all(questionId);

        // Emit question to class
        this.io.to(classId).emit('question-broadcast', {
            questionId: question.id,
            text: question.text,
            options: options.map((o) => ({ id: o.id, text: o.text })),
            timeLimit: 60, // seconds
            timestamp: new Date().toISOString(),
        });

        // Set 60-second timer
        const timerId = setTimeout(() => {
            this._compileResults(classId, questionId);
            this.activeTimers.delete(questionId);
        }, 60 * 1000);

        this.activeTimers.set(questionId, timerId);

        console.log(`❓ Question broadcast to class ${classId}: "${question.text}"`);
    }

    /**
     * Handle a student's answer submission.
     */
    handleAnswer(studentId, questionId, optionId, timeTaken) {
        // Check if already responded
        const existing = db.prepare(
            'SELECT id FROM responses WHERE student_id = ? AND question_id = ?'
        ).get(studentId, questionId);

        if (existing) return; // duplicate

        const id = uuidv4();
        db.prepare(
            'INSERT INTO responses (id, student_id, question_id, option_id, time_taken) VALUES (?, ?, ?, ?, ?)'
        ).run(id, studentId, questionId, optionId, timeTaken || 0);

        // Award points if correct
        const option = db.prepare('SELECT * FROM options WHERE id = ?').get(optionId);
        const question = db.prepare('SELECT * FROM questions WHERE id = ?').get(questionId);

        if (option && option.is_correct && question) {
            const existingPoints = db.prepare(
                'SELECT * FROM points WHERE student_id = ? AND class_id = ?'
            ).get(studentId, question.class_id);

            if (existingPoints) {
                db.prepare('UPDATE points SET score = score + 10 WHERE student_id = ? AND class_id = ?')
                    .run(studentId, question.class_id);
            } else {
                db.prepare('INSERT INTO points (id, student_id, class_id, score) VALUES (?, ?, ?, 10)')
                    .run(uuidv4(), studentId, question.class_id);
            }
        }
    }

    /**
     * Compile and broadcast results after timer ends.
     */
    _compileResults(classId, questionId) {
        const options = db.prepare('SELECT * FROM options WHERE question_id = ?').all(questionId);
        const responses = db.prepare('SELECT * FROM responses WHERE question_id = ?').all(questionId);

        const totalResponses = responses.length;
        const correctOption = options.find((o) => o.is_correct);
        const correctResponses = responses.filter((r) => r.option_id === correctOption?.id).length;

        // Count per-option responses
        const optionCounts = options.map((o) => ({
            optionId: o.id,
            text: o.text,
            is_correct: !!o.is_correct,
            count: responses.filter((r) => r.option_id === o.id).length,
        }));

        // Emit results to teacher (class room)
        this.io.to(classId).emit('question-results', {
            questionId,
            totalResponses,
            correctResponses,
            correctPercentage: totalResponses > 0 ? Math.round((correctResponses / totalResponses) * 100) : 0,
            optionBreakdown: optionCounts,
        });

        console.log(`📊 Question results: ${correctResponses}/${totalResponses} correct`);
    }
}

module.exports = { QuestionEngine };
