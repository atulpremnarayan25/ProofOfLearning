// ──────────────────────────────────────────────
// screens/classroom_screen.dart — Live classroom
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/classroom_provider.dart';
import '../providers/socket_provider.dart';
import '../widgets/video_grid.dart';
import '../widgets/chat_box.dart';
import '../widgets/popup_check.dart';
import '../widgets/question_modal.dart';

class ClassroomScreen extends StatefulWidget {
  final String classId;
  const ClassroomScreen({super.key, required this.classId});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _showChat = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = context.read<SocketProvider>();
      final classroom = context.read<ClassroomProvider>();
      final auth = context.read<AuthProvider>();

      // Connect socket if not yet
      if (!socket.isConnected && auth.token != null) {
        socket.connect(auth.token!);
        // Small delay to ensure connection
        Future.delayed(const Duration(milliseconds: 500), () {
          socket.joinRoom(widget.classId, classroom);
        });
      } else {
        socket.joinRoom(widget.classId, classroom);
      }
    });
  }

  @override
  void dispose() {
    final socket = context.read<SocketProvider>();
    socket.leaveRoom(widget.classId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classroom = context.watch<ClassroomProvider>();
    final auth = context.watch<AuthProvider>();
    final socket = context.read<SocketProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Top bar ──────────────────────
              _buildTopBar(classroom, auth),

              // ── Main content ─────────────────
              Expanded(
                child: isMobile
                    ? Column(
                        children: [
                          Expanded(flex: 3, child: _buildVideoArea(classroom)),
                          if (_showChat) Expanded(flex: 2, child: _buildChatPanel(socket, classroom)),
                        ],
                      )
                    : Row(
                        children: [
                          // Video grid
                          Expanded(flex: 3, child: _buildVideoArea(classroom)),
                          // Chat sidebar
                          if (_showChat)
                            SizedBox(
                              width: 340,
                              child: _buildChatPanel(socket, classroom),
                            ),
                        ],
                      ),
              ),

              // ── Bottom control bar ───────────
              _buildControlBar(socket, auth),
            ],
          ),

          // ── Engagement popup overlay ─────
          if (classroom.showPopup && auth.isStudent)
            PopupCheck(
              timeout: classroom.popupTimeout,
              onRespond: () {
                socket.respondToPopup(widget.classId, classroom.popupId ?? '');
                classroom.dismissPopup();
              },
              onTimeout: () {
                classroom.dismissPopup();
              },
            ),

          // ── Question modal overlay ───────
          if (classroom.showQuestion && auth.isStudent)
            QuestionModal(
              questionData: classroom.currentQuestion!,
              timeLimit: classroom.questionTimeLeft,
              onSubmit: (optionId, timeTaken) {
                socket.submitAnswer(
                  widget.classId,
                  classroom.currentQuestion!['questionId'],
                  optionId,
                  timeTaken,
                );
                classroom.dismissQuestion();
              },
              onTimeout: () {
                classroom.dismissQuestion();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ClassroomProvider classroom, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: () {
              classroom.leaveClass();
              context.go('/home');
            },
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classroom.currentClass?['title'] ?? 'Classroom',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${classroom.participants.length} participants',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          // Class code badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Code: ${classroom.currentClass?['code'] ?? ''}',
              style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          // Dashboard button (teacher only)
          if (auth.isTeacher)
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: Colors.orangeAccent),
              tooltip: 'Dashboard',
              onPressed: () => context.go('/dashboard/${widget.classId}'),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(ClassroomProvider classroom) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: VideoGrid(
        participants: classroom.participants,
        isMuted: _isMuted,
        isCameraOff: _isCameraOff,
      ),
    );
  }

  Widget _buildChatPanel(SocketProvider socket, ClassroomProvider classroom) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: ChatBox(
        messages: classroom.chatMessages,
        onSend: (msg) => socket.sendMessage(widget.classId, msg),
      ),
    );
  }

  Widget _buildControlBar(SocketProvider socket, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic toggle
          _ControlButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            color: _isMuted ? Colors.redAccent : Colors.white70,
            onTap: () => setState(() => _isMuted = !_isMuted),
          ),
          const SizedBox(width: 12),

          // Camera toggle
          _ControlButton(
            icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: _isCameraOff ? 'Start Video' : 'Stop Video',
            color: _isCameraOff ? Colors.redAccent : Colors.white70,
            onTap: () => setState(() => _isCameraOff = !_isCameraOff),
          ),
          const SizedBox(width: 12),

          // Chat toggle
          _ControlButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: _showChat ? 'Hide Chat' : 'Show Chat',
            color: _showChat ? Colors.blueAccent : Colors.white70,
            onTap: () => setState(() => _showChat = !_showChat),
          ),
          const SizedBox(width: 12),

          // Raise hand (student)
          if (auth.isStudent) ...[
            _ControlButton(
              icon: Icons.front_hand_rounded,
              label: 'Raise Hand',
              color: Colors.amberAccent,
              onTap: () => socket.raiseHand(widget.classId),
            ),
            const SizedBox(width: 12),
          ],

          // Leave button
          _ControlButton(
            icon: Icons.call_end_rounded,
            label: 'Leave',
            color: Colors.white,
            bgColor: Colors.redAccent,
            onTap: () {
              context.read<ClassroomProvider>().leaveClass();
              context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bgColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: bgColor ?? Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
