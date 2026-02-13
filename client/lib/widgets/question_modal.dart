// ──────────────────────────────────────────────
// widgets/question_modal.dart — MCQ with timer
// ──────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';

class QuestionModal extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int timeLimit;
  final Function(String optionId, int timeTaken) onSubmit;
  final VoidCallback onTimeout;

  const QuestionModal({
    super.key,
    required this.questionData,
    required this.timeLimit,
    required this.onSubmit,
    required this.onTimeout,
  });

  @override
  State<QuestionModal> createState() => _QuestionModalState();
}

class _QuestionModalState extends State<QuestionModal> {
  late int _secondsLeft;
  String? _selectedOptionId;
  Timer? _timer;
  late int _startTime;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.timeLimit;
    _startTime = DateTime.now().millisecondsSinceEpoch;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        widget.onTimeout();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit() {
    if (_selectedOptionId == null) return;
    final timeTaken = ((DateTime.now().millisecondsSinceEpoch - _startTime) / 1000).round();
    widget.onSubmit(_selectedOptionId!, timeTaken);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questionData;
    final options = List<Map<String, dynamic>>.from(question['options'] ?? []);
    final progress = _secondsLeft / widget.timeLimit;
    final isUrgent = _secondsLeft <= 15;

    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.15),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: Colors.purpleAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Understanding Check',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUrgent ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: isUrgent ? Colors.redAccent : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_secondsLeft}s',
                          style: TextStyle(
                            color: isUrgent ? Colors.redAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation(isUrgent ? Colors.redAccent : Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 20),

              // Question text
              Text(
                question['text'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
              ),
              const SizedBox(height: 20),

              // Options
              ...options.map((opt) {
                final isSelected = _selectedOptionId == opt['id'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedOptionId = opt['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blueAccent.withOpacity(0.15)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.08),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.blueAccent : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.blueAccent : Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              opt['text'] ?? '',
                              style: TextStyle(
                                color: isSelected ? Colors.blueAccent : Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedOptionId != null ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    disabledBackgroundColor: Colors.white.withOpacity(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Submit Answer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
