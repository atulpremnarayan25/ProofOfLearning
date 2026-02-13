// ──────────────────────────────────────────────
// widgets/analytics_charts.dart — fl_chart widgets
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsCharts extends StatelessWidget {
  final List<Map<String, dynamic>> students;

  const AnalyticsCharts({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No student data available', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Column(
      children: [
        // ── Attendance Pie Chart ─────────────
        _ChartContainer(
          title: 'Attendance',
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: _buildAttendancePie(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Engagement Bar Chart ─────────────
        _ChartContainer(
          title: 'Student Engagement Scores',
          child: SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final name = groupIndex < students.length ? students[groupIndex]['name'] : '';
                      return BarTooltipItem(
                        '$name\n${rod.toY.round()}%',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < students.length) {
                          final name = students[idx]['name'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 6 ? '${name.substring(0, 6)}..' : name,
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(color: Colors.white24, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildEngagementBars(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Score Breakdown Line Chart ────────
        _ChartContainer(
          title: 'Score Breakdown (Attendance / Focus / Understanding)',
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < students.length) {
                          final name = students[idx]['name'] ?? '';
                          return Text(
                            name.length > 4 ? '${name.substring(0, 4)}..' : name,
                            style: const TextStyle(color: Colors.white24, fontSize: 9),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(color: Colors.white24, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: _buildScoreLines(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildAttendancePie() {
    final present = students.where((s) => s['is_present'] == true).length;
    final absent = students.length - present;

    return [
      PieChartSectionData(
        value: present.toDouble(),
        color: Colors.greenAccent.shade400,
        title: 'Present\n$present',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        radius: 55,
      ),
      PieChartSectionData(
        value: absent.toDouble(),
        color: Colors.redAccent,
        title: 'Absent\n$absent',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        radius: 50,
      ),
    ];
  }

  List<BarChartGroupData> _buildEngagementBars() {
    return students.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final score = (s['engagement_score'] ?? 0).toDouble();

      Color barColor;
      if (score >= 80) {
        barColor = Colors.greenAccent.shade400;
      } else if (score >= 50) {
        barColor = Colors.orangeAccent;
      } else {
        barColor = Colors.redAccent;
      }

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: score,
            color: barColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();
  }

  List<LineChartBarData> _buildScoreLines() {
    // Attendance line
    final attendanceSpots = students.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['attendance_score'] ?? 0).toDouble());
    }).toList();

    // Focus line
    final focusSpots = students.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['focus_score'] ?? 0).toDouble());
    }).toList();

    // Understanding line
    final understandingSpots = students.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['understanding_score'] ?? 0).toDouble());
    }).toList();

    return [
      LineChartBarData(
        spots: attendanceSpots,
        color: Colors.blueAccent,
        barWidth: 2,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.05)),
      ),
      LineChartBarData(
        spots: focusSpots,
        color: Colors.greenAccent,
        barWidth: 2,
        dotData: const FlDotData(show: true),
      ),
      LineChartBarData(
        spots: understandingSpots,
        color: Colors.purpleAccent,
        barWidth: 2,
        dotData: const FlDotData(show: true),
      ),
    ];
  }
}

class _ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
