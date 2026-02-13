// ──────────────────────────────────────────────
// services/analyticsEngine.js — Score computation
// ──────────────────────────────────────────────
const db = require('../db');

class AnalyticsEngine {
    /**
     * Compute engagement score for a student in a class.
     * engagement = 0.5 * attendance + 0.3 * focus + 0.2 * understanding
     */
    static computeEngagement(studentId, classId) {
        const attendance = AnalyticsEngine.getAttendanceScore(studentId, classId);
        const focus = AnalyticsEngine.getFocusScore(studentId, classId);
        const understanding = AnalyticsEngine.getUnderstandingScore(studentId, classId);

        return {
            attendance: Math.round(attendance * 100),
            focus: Math.round(focus * 100),
            understanding: Math.round(understanding * 100),
            engagement: Math.round((0.5 * attendance + 0.3 * focus + 0.2 * understanding) * 100),
            isPresent: attendance >= 0.8,
        };
    }

    /**
     * Attendance = responded_popups / total_popups
     */
    static getAttendanceScore(studentId, classId) {
        const total = db.prepare(
            'SELECT COUNT(*) as c FROM popup_logs WHERE class_id = ? AND student_id = ?'
        ).get(classId, studentId).c;

        if (total === 0) return 1; // No popups yet → assume present

        const responded = db.prepare(
            'SELECT COUNT(*) as c FROM popup_logs WHERE class_id = ? AND student_id = ? AND responded = 1'
        ).get(classId, studentId).c;

        return responded / total;
    }

    /**
     * Focus = time_focused / (time_focused + time_blurred)
     */
    static getFocusScore(studentId, classId) {
        const logs = db.prepare(
            'SELECT event_type, duration FROM focus_logs WHERE class_id = ? AND student_id = ?'
        ).all(classId, studentId);

        const focusTime = logs.filter((l) => l.event_type === 'focus').reduce((s, l) => s + l.duration, 0);
        const blurTime = logs.filter((l) => l.event_type === 'blur').reduce((s, l) => s + l.duration, 0);
        const total = focusTime + blurTime;

        return total > 0 ? focusTime / total : 1;
    }

    /**
     * Understanding = correct_answers / total_questions
     */
    static getUnderstandingScore(studentId, classId) {
        const totalQ = db.prepare(
            'SELECT COUNT(*) as c FROM questions WHERE class_id = ?'
        ).get(classId).c;

        if (totalQ === 0) return 0;

        const correct = db.prepare(`
      SELECT COUNT(*) as c FROM responses r
      JOIN options o ON o.id = r.option_id
      JOIN questions q ON q.id = r.question_id
      WHERE r.student_id = ? AND q.class_id = ? AND o.is_correct = 1
    `).get(studentId, classId).c;

        return correct / totalQ;
    }
}

module.exports = { AnalyticsEngine };
