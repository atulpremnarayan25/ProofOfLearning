// ──────────────────────────────────────────────
// providers/socket_provider.dart — Socket.IO lifecycle
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'classroom_provider.dart';

class SocketProvider extends ChangeNotifier {
  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;
  // Set at build time: --dart-define=SOCKET_URL=https://your-render-url.onrender.com
  static const String _socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://localhost:5001',
  );

  /// Connect to the Socket.IO server with JWT auth.
  void connect(String token) {
    _socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('🔌 Socket connected');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('🔌 Socket disconnected');
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      debugPrint('🔌 Socket connection error: $err');
    });
  }

  /// Join a classroom room.
  void joinRoom(String classId, ClassroomProvider classroomProvider) {
    _socket?.emit('join-room', {'classId': classId});

    // Listen for participants list
    _socket?.on('participants-list', (data) {
      final list = (data as List)
          .map((d) => Participant.fromMap(Map<String, dynamic>.from(d)))
          .toList();
      classroomProvider.setParticipants(list);
    });

    // Listen for new user
    _socket?.on('user-joined', (data) {
      classroomProvider.addParticipant(
        Participant.fromMap(Map<String, dynamic>.from(data)),
      );
    });

    // Listen for user left
    _socket?.on('user-left', (data) {
      classroomProvider.removeParticipant(data['userId']);
    });

    // Listen for chat messages
    _socket?.on('chat-message', (data) {
      classroomProvider.addChatMessage(
        ChatMessage.fromMap(Map<String, dynamic>.from(data)),
      );
    });

    // Listen for hand raised
    _socket?.on('hand-raised', (data) {
      debugPrint('✋ Hand raised: ${data['name']}');
    });

    // Listen for engagement popups
    _socket?.on('engagement-popup', (data) {
      classroomProvider.triggerPopup(
        data['popupId'],
        data['timeout'] ?? 15,
      );
    });

    // Listen for question broadcast
    _socket?.on('question-broadcast', (data) {
      classroomProvider.triggerQuestion(
        Map<String, dynamic>.from(data),
        data['timeLimit'] ?? 60,
      );
    });

    // Listen for question results
    _socket?.on('question-results', (data) {
      debugPrint('📊 Question results: ${data['correctPercentage']}% correct');
    });
  }

  /// Leave a classroom room.
  void leaveRoom(String classId) {
    _socket?.emit('leave-room', {'classId': classId});
    _socket?.off('participants-list');
    _socket?.off('user-joined');
    _socket?.off('user-left');
    _socket?.off('chat-message');
    _socket?.off('hand-raised');
    _socket?.off('engagement-popup');
    _socket?.off('question-broadcast');
    _socket?.off('question-results');
  }

  /// Send a chat message.
  void sendMessage(String classId, String message) {
    _socket?.emit('chat-message', {'classId': classId, 'message': message});
  }

  /// Raise hand.
  void raiseHand(String classId) {
    _socket?.emit('raise-hand', {'classId': classId});
  }

  /// Respond to engagement popup.
  void respondToPopup(String classId, String popupId) {
    _socket?.emit('popup-response', {'classId': classId, 'popupId': popupId});
  }

  /// Trigger a question (teacher only).
  void triggerQuestion(String classId, String questionId) {
    _socket?.emit('trigger-question', {'classId': classId, 'questionId': questionId});
  }

  /// Submit answer to a question.
  void submitAnswer(String classId, String questionId, String optionId, int timeTaken) {
    _socket?.emit('submit-answer', {
      'classId': classId,
      'questionId': questionId,
      'optionId': optionId,
      'timeTaken': timeTaken,
    });
  }

  /// Send focus event.
  void sendFocusEvent(String classId, String eventType, int duration) {
    _socket?.emit('focus-event', {
      'classId': classId,
      'eventType': eventType,
      'duration': duration,
    });
  }

  // ── WebRTC signaling ───────────────────────
  void sendWebRTCOffer(String classId, String targetUserId, dynamic offer) {
    _socket?.emit('webrtc-offer', {
      'classId': classId,
      'targetUserId': targetUserId,
      'offer': offer,
    });
  }

  void sendWebRTCAnswer(String classId, String targetUserId, dynamic answer) {
    _socket?.emit('webrtc-answer', {
      'classId': classId,
      'targetUserId': targetUserId,
      'answer': answer,
    });
  }

  void sendICECandidate(String classId, String targetUserId, dynamic candidate) {
    _socket?.emit('webrtc-ice-candidate', {
      'classId': classId,
      'targetUserId': targetUserId,
      'candidate': candidate,
    });
  }

  void onWebRTCOffer(Function(Map<String, dynamic>) callback) {
    _socket?.on('webrtc-offer', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onWebRTCAnswer(Function(Map<String, dynamic>) callback) {
    _socket?.on('webrtc-answer', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onICECandidate(Function(Map<String, dynamic>) callback) {
    _socket?.on('webrtc-ice-candidate', (data) => callback(Map<String, dynamic>.from(data)));
  }

  /// Disconnect from socket.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }
}
