import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/learning_scheduler.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int> _srStats = {};
  Map<String, int> _studyHistory = {};
  List<Map<String, dynamic>> _quizHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final scheduler = LearningScheduler.instance;
    final stats = await scheduler.getStats();
    final history = await scheduler.getStudyHistory(7);
    final quizHistory = await scheduler.getQuizHistory();
    if (mounted) {
      setState(() {
        _srStats = stats;
        _studyHistory = history;
        _quizHistory = quizHistory;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF48A9A6),
        title: const Text('Bảng phân tích học tập'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildStudyChart(),
                  const SizedBox(height: 24),
                  _buildQuizHistorySection(),
                  const SizedBox(height: 24),
                  _buildStreakSection(),
                ],
              ),
            ),
    );
  }

  // ─── Overview cards ───
  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tổng quan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.style, 
              label: 'Thẻ đã học', 
              value: '${_srStats['total'] ?? 0}', 
              color: Colors.teal,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.alarm, 
              label: 'Cần ôn lại', 
              value: '${_srStats['due'] ?? 0}', 
              color: Colors.orange,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.emoji_events, 
              label: 'Đã thuộc', 
              value: '${_srStats['mastered'] ?? 0}', 
              color: Colors.amber,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.quiz, 
              label: 'Bài quiz', 
              value: '${_quizHistory.length}', 
              color: Colors.deepPurple,
            )),
          ],
        ),
      ],
    );
  }

  // ─── Study time chart (last 7 days) ───
  Widget _buildStudyChart() {
    final entries = _studyHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thời gian học (7 ngày qua)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Đơn vị: phút', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: entries.isEmpty
                ? Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey.shade400)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (entries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b) + 10).clamp(10, 500),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.round()} phút',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                              if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                              final day = entries[idx].key.substring(5); // MM-DD
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(day, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: List.generate(entries.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value.toDouble(),
                              color: const Color(0xFF48A9A6),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Quiz history ───
  Widget _buildQuizHistorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lịch sử Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_quizHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Chưa có bài quiz nào', style: TextStyle(color: Colors.grey.shade400))),
            )
          else
            ...(_quizHistory.reversed.take(10).map((q) {
              final correct = q['correct'] as int? ?? 0;
              final total = q['total'] as int? ?? 1;
              final pct = (correct / total * 100).round();
              final dateStr = q['date'] as String? ?? '';
              final date = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: pct >= 70 ? Colors.green.shade50 : Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('$pct%', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: pct >= 70 ? Colors.green.shade700 : Colors.orange.shade700,
                        )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$correct / $total câu đúng', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Icon(
                      pct >= 70 ? Icons.thumb_up : Icons.trending_up,
                      color: pct >= 70 ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }

  // ─── Streak section ───
  Widget _buildStreakSection() {
    // Calculate current streak from study history
    int streak = 0;
    final sortedDates = _studyHistory.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    for (final entry in sortedDates) {
      if (entry.value > 0) {
        streak++;
      } else {
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🔥', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$streak ngày liên tiếp',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  streak > 0 ? 'Tuyệt vời! Hãy duy trì phong độ nhé! 💪' : 'Hãy bắt đầu học hôm nay! 📚',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color.shade700, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade700)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
