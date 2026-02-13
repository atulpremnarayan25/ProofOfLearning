// ──────────────────────────────────────────────
// providers/classroom_provider.dart — Classroom state
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatMessage {
  final String userId;
  final String name;
  final String message;
  final String timestamp;

  ChatMessage({
    required this.userId,
    required this.name,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? '',
    );
  }
}

class Participant {
  final String userId;
  final String name;
  final String role;

  Participant({required this.userId, required this.name, required this.role});

  factory Participant.fromMap(Map<String, dynamic> data) {
    return Participant(
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'student',
    );
  }
}

class ClassroomProvider extends ChangeNotifier {
  final ApiService _api;

  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _currentClass;
  List<Participant> _participants = [];
  List<ChatMessage> _chatMessages = [];
  bool _isLoading = false;
  String? _error;

  // Engagement popup state
  bool _showPopup = false;
  String? _popupId;
  int _popupTimeout = 15;

  // Question state
  bool _showQuestion = false;
  Map<String, dynamic>? _currentQuestion;
  int _questionTimeLeft = 60;

  ClassroomProvider(this._api);

  // Getters
  List<Map<String, dynamic>> get classes => _classes;
  Map<String, dynamic>? get currentClass => _currentClass;
  List<Participant> get participants => _participants;
  List<ChatMessage> get chatMessages => _chatMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showPopup => _showPopup;
  String? get popupId => _popupId;
  int get popupTimeout => _popupTimeout;
  bool get showQuestion => _showQuestion;
  Map<String, dynamic>? get currentQuestion => _currentQuestion;
  int get questionTimeLeft => _questionTimeLeft;

  /// Load all classes for the current user.
  Future<void> loadClasses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.listClasses();
      _classes = List<Map<String, dynamic>>.from(res.data);
      _error = null;
    } catch (e) {
      _error = 'Failed to load classes';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new classroom (teacher only).
  Future<Map<String, dynamic>?> createClass(String title) async {
    try {
      final res = await _api.createClass(title);
      final newClass = Map<String, dynamic>.from(res.data);
      _classes.insert(0, newClass);
      notifyListeners();
      return newClass;
    } catch (e) {
      _error = 'Failed to create class';
      notifyListeners();
      return null;
    }
  }

  /// Join a classroom with code (student).
  Future<Map<String, dynamic>?> joinClass(String code) async {
    try {
      final res = await _api.joinClass(code);
      final joined = Map<String, dynamic>.from(res.data);
      await loadClasses(); // Refresh list
      return joined;
    } catch (e) {
      _error = 'Failed to join class. Check the code.';
      notifyListeners();
      return null;
    }
  }

  /// Set current class when entering a classroom.
  void setCurrentClass(Map<String, dynamic> cls) {
    _currentClass = cls;
    _chatMessages.clear();
    _participants.clear();
    notifyListeners();
  }

  /// Update participants list.
  void setParticipants(List<Participant> list) {
    _participants = list;
    notifyListeners();
  }

  void addParticipant(Participant p) {
    if (!_participants.any((x) => x.userId == p.userId)) {
      _participants.add(p);
      notifyListeners();
    }
  }

  void removeParticipant(String userId) {
    _participants.removeWhere((p) => p.userId == userId);
    notifyListeners();
  }

  /// Add a chat message.
  void addChatMessage(ChatMessage msg) {
    _chatMessages.add(msg);
    notifyListeners();
  }

  /// Show engagement popup.
  void triggerPopup(String popupId, int timeout) {
    _showPopup = true;
    _popupId = popupId;
    _popupTimeout = timeout;
    notifyListeners();
  }

  void dismissPopup() {
    _showPopup = false;
    _popupId = null;
    notifyListeners();
  }

  /// Show question modal.
  void triggerQuestion(Map<String, dynamic> question, int timeLimit) {
    _showQuestion = true;
    _currentQuestion = question;
    _questionTimeLeft = timeLimit;
    notifyListeners();
  }

  void dismissQuestion() {
    _showQuestion = false;
    _currentQuestion = null;
    notifyListeners();
  }

  void updateQuestionTimeLeft(int seconds) {
    _questionTimeLeft = seconds;
    notifyListeners();
  }

  /// Clear current class state.
  void leaveClass() {
    _currentClass = null;
    _chatMessages.clear();
    _participants.clear();
    _showPopup = false;
    _showQuestion = false;
    notifyListeners();
  }
}
