// ──────────────────────────────────────────────
// services/engagementEngine.js — Random attendance popups
// ──────────────────────────────────────────────
const { v4: uuidv4 } = require('uuid');
const db = require('../db');

class EngagementEngine {
    constructor(io) {
        this.io = io;
        // Map<classId, intervalId>
        this.intervals = new Map();
    }

    /**
     * Start scheduling random popups for a class.
     * Popups fire every 3–7 minutes (random interval per cycle).
     */
    startForClass(classId) {
        if (this.intervals.has(classId)) return; // already running

        const scheduleNext = () => {
            // Random delay between 3 and 7 minutes (in ms)
            const delayMs = (Math.floor(Math.random() * 5) + 3) * 60 * 1000;

            const timeoutId = setTimeout(() => {
                this._sendPopup(classId);
                // Schedule the next one
                scheduleNext();
            }, delayMs);

            this.intervals.set(classId, timeoutId);
        };

        // Also send a first popup after 2 minutes to start engagement early
        const firstTimeout = setTimeout(() => {
            this._sendPopup(classId);
            scheduleNext();
        }, 2 * 60 * 1000);

        this.intervals.set(classId, firstTimeout);
        console.log(`⏰ Engagement engine started for class ${classId}`);
    }

    /**
     * Stop popups for a class.
     */
    stopForClass(classId) {
        if (this.intervals.has(classId)) {
            clearTimeout(this.intervals.get(classId));
            this.intervals.delete(classId);
            console.log(`⏹️  Engagement engine stopped for class ${classId}`);
        }
    }

    /**
     * Broadcast a popup to all students in a class.
     */
    _sendPopup(classId) {
        const popupId = uuidv4();

        // Get enrolled students
        const students = db.prepare(`
      SELECT student_id FROM enrollments WHERE class_id = ?
    `).all(classId);

        // Create popup log entries for each student (responded = 0 by default)
        const insert = db.prepare(
            'INSERT INTO popup_logs (id, class_id, student_id, responded) VALUES (?, ?, ?, 0)'
        );

        for (const s of students) {
            insert.run(uuidv4(), classId, s.student_id);
        }

        // Emit popup to the room
        this.io.to(classId).emit('engagement-popup', {
            popupId,
            classId,
            timeout: 15, // seconds to respond
            timestamp: new Date().toISOString(),
        });

        console.log(`🔔 Popup sent to class ${classId} (${students.length} students)`);
    }

    /**
     * Handle a student's popup response.
     */
    handleResponse(classId, studentId, popupId) {
        // Mark the most recent un-responded popup for this student as responded
        db.prepare(`
      UPDATE popup_logs SET responded = 1
      WHERE class_id = ? AND student_id = ? AND responded = 0
      ORDER BY created_at DESC LIMIT 1
    `).run(classId, studentId);

        console.log(`✅ Popup response from student ${studentId} in class ${classId}`);
    }
}

module.exports = { EngagementEngine };
