// ──────────────────────────────────────────────
// widgets/popup_check.dart — Engagement popup
// ──────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';

class PopupCheck extends StatefulWidget {
  final int timeout;
  final VoidCallback onRespond;
  final VoidCallback onTimeout;

  const PopupCheck({
    super.key,
    required this.timeout,
    required this.onRespond,
    required this.onTimeout,
  });

  @override
  State<PopupCheck> createState() => _PopupCheckState();
}

class _PopupCheckState extends State<PopupCheck> with SingleTickerProviderStateMixin {
  late int _secondsLeft;
  Timer? _timer;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.timeout;

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

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
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / widget.timeout;
    final isUrgent = _secondsLeft <= 5;

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: ScaleTransition(
          scale: _bounceAnim,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isUrgent
                    ? [const Color(0xFF2C003E), const Color(0xFF6B0020)]
                    : [const Color(0xFF0F0C29), const Color(0xFF302B63)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isUrgent ? Colors.redAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isUrgent ? Colors.redAccent : Colors.blueAccent).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.front_hand_rounded,
                  color: isUrgent ? Colors.redAccent : Colors.amberAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you still here?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button to confirm your attendance',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Circular progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(
                          isUrgent ? Colors.redAccent : Colors.blueAccent,
                        ),
                      ),
                    ),
                    Text(
                      '$_secondsLeft',
                      style: TextStyle(
                        color: isUrgent ? Colors.redAccent : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Respond button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.onRespond,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUrgent ? Colors.redAccent : Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "I'm Here! ✋",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
