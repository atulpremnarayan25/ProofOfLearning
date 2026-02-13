// ──────────────────────────────────────────────
// screens/dashboard_screen.dart — Teacher analytics
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/leaderboard.dart';

class DashboardScreen extends StatefulWidget {
  final String classId;
  const DashboardScreen({super.key, required this.classId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    try {
      final analyticsRes = await api.getAnalytics(widget.classId);
      final leaderboardRes = await api.getLeaderboard(widget.classId);

      setState(() {
        _analytics = Map<String, dynamic>.from(analyticsRes.data);
        _leaderboard = List<Map<String, dynamic>>.from(leaderboardRes.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          onPressed: () => context.go('/classroom/${widget.classId}'),
        ),
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _analytics == null
              ? const Center(
                  child: Text('Failed to load analytics', style: TextStyle(color: Colors.white54)),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Summary cards ───────────
                        _buildSummaryCards(),
                        const SizedBox(height: 24),

                        // ── Charts ──────────────────
                        const Text(
                          'Engagement Overview',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        AnalyticsCharts(
                          students: List<Map<String, dynamic>>.from(_analytics!['students'] ?? []),
                        ),
                        const SizedBox(height: 32),

                        // ── Leaderboard ─────────────
                        const Text(
                          'Leaderboard',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LeaderboardWidget(entries: _leaderboard),
                        const SizedBox(height: 32),

                        // ── Student table ───────────
                        const Text(
                          'Student Details',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildStudentTable(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _analytics!['total_students'] ?? 0;
    final present = _analytics!['present_count'] ?? 0;
    final absent = _analytics!['absent_count'] ?? 0;
    final avgEngagement = _analytics!['avg_engagement'] ?? 0;
    final avgUnderstanding = _analytics!['avg_understanding'] ?? 0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _SummaryCard(
          title: 'Total Students',
          value: '$total',
          icon: Icons.people_rounded,
          color: Colors.blueAccent,
        ),
        _SummaryCard(
          title: 'Present',
          value: '$present',
          icon: Icons.check_circle_rounded,
          color: Colors.greenAccent.shade400,
        ),
        _SummaryCard(
          title: 'Absent',
          value: '$absent',
          icon: Icons.cancel_rounded,
          color: Colors.redAccent,
        ),
        _SummaryCard(
          title: 'Avg Engagement',
          value: '$avgEngagement%',
          icon: Icons.trending_up_rounded,
          color: Colors.orangeAccent,
        ),
        _SummaryCard(
          title: 'Avg Understanding',
          value: '$avgUnderstanding%',
          icon: Icons.psychology_rounded,
          color: Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildStudentTable() {
    final students = List<Map<String, dynamic>>.from(_analytics!['students'] ?? []);

    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No students enrolled yet', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateColor.resolveWith(
            (_) => Colors.white.withOpacity(0.05),
          ),
          columns: const [
            DataColumn(label: Text('Name', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Status', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Attendance', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Focus', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Understanding', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Engagement', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Points', style: TextStyle(color: Colors.white70))),
          ],
          rows: students.map((s) {
            final isPresent = s['is_present'] ?? false;
            return DataRow(cells: [
              DataCell(Text(s['name'] ?? '', style: const TextStyle(color: Colors.white))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Absent',
                    style: TextStyle(
                      color: isPresent ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(Text('${s['attendance_score']}%', style: const TextStyle(color: Colors.white70))),
              DataCell(Text('${s['focus_score']}%', style: const TextStyle(color: Colors.white70))),
              DataCell(Text('${s['understanding_score']}%', style: const TextStyle(color: Colors.white70))),
              DataCell(_EngagementBadge(score: s['engagement_score'] ?? 0)),
              DataCell(Text('${s['points']}', style: const TextStyle(color: Colors.amberAccent))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        ],
      ),
    );
  }
}

class _EngagementBadge extends StatelessWidget {
  final int score;
  const _EngagementBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80) {
      color = Colors.greenAccent;
    } else if (score >= 50) {
      color = Colors.orangeAccent;
    } else {
      color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$score%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
