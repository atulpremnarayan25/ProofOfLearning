// ──────────────────────────────────────────────
// widgets/video_grid.dart — WebRTC video grid
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../providers/classroom_provider.dart';

class VideoGrid extends StatelessWidget {
  final List<Participant> participants;
  final bool isMuted;
  final bool isCameraOff;

  const VideoGrid({
    super.key,
    required this.participants,
    required this.isMuted,
    required this.isCameraOff,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.white.withOpacity(0.2), size: 64),
            const SizedBox(height: 16),
            Text(
              'Waiting for participants...',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Calculate grid dimensions
    final count = participants.length;
    final crossAxisCount = count <= 1
        ? 1
        : count <= 4
            ? 2
            : count <= 9
                ? 3
                : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: count,
      itemBuilder: (ctx, i) => _VideoTile(participant: participants[i]),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final Participant participant;
  const _VideoTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    // Color based on role
    final isTeacher = participant.role == 'teacher';
    final borderColor = isTeacher ? Colors.orangeAccent : Colors.blueAccent;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 2),
      ),
      child: Stack(
        children: [
          // Avatar placeholder (would be RTCVideoView in real WebRTC)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: borderColor.withOpacity(0.15),
                  child: Text(
                    participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: borderColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  participant.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Role badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isTeacher ? 'Teacher' : 'Student',
                style: TextStyle(color: borderColor, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Name tag at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      participant.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
