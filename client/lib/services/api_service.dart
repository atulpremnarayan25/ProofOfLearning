// ──────────────────────────────────────────────
// services/api_service.dart — Centralized HTTP client
// ──────────────────────────────────────────────
import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5001/api';

  final Dio _dio;
  String? _token;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ));

  void setToken(String token) {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _token = null;
    _dio.options.headers.remove('Authorization');
  }

  String? get token => _token;

  // ── Auth ───────────────────────────────────
  Future<Response> register(String name, String email, String password, String role) {
    return _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
  }

  Future<Response> login(String email, String password) {
    return _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  // ── Classroom ──────────────────────────────
  Future<Response> createClass(String title) {
    return _dio.post('/classroom/create', data: {'title': title});
  }

  Future<Response> joinClass(String code) {
    return _dio.post('/classroom/join', data: {'code': code});
  }

  Future<Response> listClasses() {
    return _dio.get('/classroom/list');
  }

  Future<Response> getClass(String classId) {
    return _dio.get('/classroom/$classId');
  }

  Future<Response> activateClass(String classId) {
    return _dio.post('/classroom/$classId/activate');
  }

  Future<Response> deactivateClass(String classId) {
    return _dio.post('/classroom/$classId/deactivate');
  }

  // ── Questions ──────────────────────────────
  Future<Response> createQuestion(String classId, String text, List<Map<String, dynamic>> options) {
    return _dio.post('/questions/create', data: {
      'class_id': classId,
      'text': text,
      'options': options,
    });
  }

  Future<Response> respondToQuestion(String questionId, String optionId, int timeTaken) {
    return _dio.post('/questions/respond', data: {
      'question_id': questionId,
      'option_id': optionId,
      'time_taken': timeTaken,
    });
  }

  Future<Response> getQuestionResults(String classId) {
    return _dio.get('/questions/$classId/results');
  }

  // ── Analytics ──────────────────────────────
  Future<Response> getAnalytics(String classId) {
    return _dio.get('/analytics/$classId');
  }

  Future<Response> getLeaderboard(String classId) {
    return _dio.get('/analytics/$classId/leaderboard');
  }
}
