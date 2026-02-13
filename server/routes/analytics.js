// ──────────────────────────────────────────────
// routes/analytics.js — Teacher analytics endpoint
// ──────────────────────────────────────────────
const express = require('express');
const db = require('../db');
const { authMiddleware } = require('../middlewares/auth');

const router = express.Router();
router.use(authMiddleware);

// ── GET /api/analytics/:classId ────────────────
router.get('/:classId', (req, res) => {
    try {
        const classId = req.params.classId;

        // Get enrolled students
        const students = db.prepare(`
      SELECT u.id, u.name, u.email FROM users u
      JOIN enrollments e ON e.student_id = u.id
      WHERE e.class_id = ?
    `).all(classId);

        // Compute per-student analytics
        const studentAnalytics = students.map((student) => {
            // ── Attendance score (popup responses) ──
            const totalPopups = db.prepare(
                'SELECT COUNT(*) as count FROM popup_logs WHERE class_id = ? AND student_id = ?'
            ).get(classId, student.id).count;

            const respondedPopups = db.prepare(
                'SELECT COUNT(*) as count FROM popup_logs WHERE class_id = ? AND student_id = ? AND responded = 1'
            ).get(classId, student.id).count;

            const attendanceScore = totalPopups > 0 ? respondedPopups / totalPopups : 1;
            const isPresent = attendanceScore >= 0.8;

            // ── Focus score ──
            const focusLogs = db.prepare(
                'SELECT * FROM focus_logs WHERE class_id = ? AND student_id = ?'
            ).all(classId, student.id);

            const totalFocusTime = focusLogs
                .filter((l) => l.event_type === 'focus')
                .reduce((sum, l) => sum + l.duration, 0);
            const totalBlurTime = focusLogs
                .filter((l) => l.event_type === 'blur')
                .reduce((sum, l) => sum + l.duration, 0);
            const totalTime = totalFocusTime + totalBlurTime;
            const focusScore = totalTime > 0 ? totalFocusTime / totalTime : 1;

            // ── Understanding score (question accuracy) ──
            const totalQuestions = db.prepare(
                'SELECT COUNT(*) as count FROM questions WHERE class_id = ?'
            ).get(classId).count;

            const correctAnswers = db.prepare(`
        SELECT COUNT(*) as count FROM responses r
        JOIN options o ON o.id = r.option_id
        JOIN questions q ON q.id = r.question_id
        WHERE r.student_id = ? AND q.class_id = ? AND o.is_correct = 1
      `).get(student.id, classId).count;

            const understandingScore = totalQuestions > 0 ? correctAnswers / totalQuestions : 0;

            // ── Composite engagement score ──
            const engagementScore = 0.5 * attendanceScore + 0.3 * focusScore + 0.2 * understandingScore;

            // ── Points (gamification) ──
            const pointsRow = db.prepare(
                'SELECT score FROM points WHERE student_id = ? AND class_id = ?'
            ).get(student.id, classId);

            return {
                student_id: student.id,
                name: student.name,
                email: student.email,
                attendance_score: Math.round(attendanceScore * 100),
                is_present: isPresent,
                focus_score: Math.round(focusScore * 100),
                understanding_score: Math.round(understandingScore * 100),
                engagement_score: Math.round(engagementScore * 100),
                points: pointsRow ? pointsRow.score : 0,
            };
        });

        // ── Class-level summary ──
        const totalStudents = students.length;
        const presentCount = studentAnalytics.filter((s) => s.is_present).length;
        const avgEngagement = totalStudents > 0
            ? Math.round(studentAnalytics.reduce((sum, s) => sum + s.engagement_score, 0) / totalStudents)
            : 0;
        const avgUnderstanding = totalStudents > 0
            ? Math.round(studentAnalytics.reduce((sum, s) => sum + s.understanding_score, 0) / totalStudents)
            : 0;

        res.json({
            class_id: classId,
            total_students: totalStudents,
            present_count: presentCount,
            absent_count: totalStudents - presentCount,
            avg_engagement: avgEngagement,
            avg_understanding: avgUnderstanding,
            students: studentAnalytics,
        });
    } catch (err) {
        console.error('Analytics error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ── GET /api/analytics/:classId/leaderboard ────
router.get('/:classId/leaderboard', (req, res) => {
    try {
        const leaderboard = db.prepare(`
      SELECT u.id, u.name, p.score FROM points p
      JOIN users u ON u.id = p.student_id
      WHERE p.class_id = ?
      ORDER BY p.score DESC
    `).all(req.params.classId);

        res.json(leaderboard);
    } catch (err) {
        console.error('Leaderboard error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
