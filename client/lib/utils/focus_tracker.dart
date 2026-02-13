// ──────────────────────────────────────────────
// utils/focus_tracker.dart — App lifecycle tracking
// ──────────────────────────────────────────────
import 'package:flutter/widgets.dart';
import '../providers/socket_provider.dart';

/// Tracks app lifecycle state and reports focus/blur events
/// to the server via socket. Attach this as a mixin or
/// use it as a standalone observer.
class FocusTracker with WidgetsBindingObserver {
  final SocketProvider _socket;
  final String _classId;

  DateTime? _lastPauseTime;
  DateTime? _lastResumeTime;
  bool _isActive = true;

  FocusTracker({
    required SocketProvider socket,
    required String classId,
  })  : _socket = socket,
        _classId = classId;

  /// Call this in initState to start tracking.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _lastResumeTime = DateTime.now();
    _isActive = true;
  }

  /// Call this in dispose to stop tracking.
  void stop() {
    // Report final focus duration
    if (_isActive && _lastResumeTime != null) {
      final duration = DateTime.now().difference(_lastResumeTime!).inSeconds;
      _socket.sendFocusEvent(_classId, 'focus', duration);
    }
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _onBlur();
        break;
      case AppLifecycleState.resumed:
        _onFocus();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onBlur() {
    if (!_isActive) return;
    _isActive = false;
    _lastPauseTime = DateTime.now();

    // Report focus duration
    if (_lastResumeTime != null) {
      final focusDuration = _lastPauseTime!.difference(_lastResumeTime!).inSeconds;
      _socket.sendFocusEvent(_classId, 'focus', focusDuration);
    }
  }

  void _onFocus() {
    if (_isActive) return;
    _isActive = true;
    _lastResumeTime = DateTime.now();

    // Report blur duration
    if (_lastPauseTime != null) {
      final blurDuration = _lastResumeTime!.difference(_lastPauseTime!).inSeconds;
      _socket.sendFocusEvent(_classId, 'blur', blurDuration);
    }
  }
}
