import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

enum _Range { weekly, monthly }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Range _range = _Range.weekly;
  List<DailyStat>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final analytics = context.read<AppProvider>().analytics;
    final stats = _range == _Range.weekly
        ? await analytics.getWeeklyStats()
        : await analytics.getMonthlyStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ስታትስቲክስ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<_Range>(
              segments: const [
                ButtonSegment(value: _Range.weekly, label: Text('ሳምንታዊ')),
                ButtonSegment(value: _Range.monthly, label: Text('ወርሃዊ')),
              ],
              selected: {_range},
              onSelectionChanged: (s) {
                setState(() => _range = s.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_stats == null || _stats!.every((s) => s.tasksTotal == 0 && s.habitsTotal == 0 && s.journalRatingSum == 0))
              const Expanded(
                child: Center(child: Text('ገና በቂ ውሂብ የለም — ተግባራት/ልምዶች መመዝገብ ይጀምሩ።')),
              )
            else ...[
              _SummaryRow(stats: _stats!),
              const SizedBox(height: 20),
              Expanded(child: _ScoreChart(stats: _stats!, showEveryLabel: _range == _Range.weekly)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<DailyStat> stats;
  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final avg = stats.map((s) => s.score).reduce((a, b) => a + b) / stats.length;
    final best = stats.reduce((a, b) => a.score >= b.score ? a : b);

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.teal, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            stat('አማካይ ውጤት', '${avg.toStringAsFixed(0)}%'),
            stat('ምርጥ ቀን', '${best.score.toStringAsFixed(0)}%'),
            stat('የተመዘገቡ ቀናት',
                '${stats.where((s) => s.tasksTotal > 0 || s.habitsTotal > 0 || s.journalRatingSum > 0).length}'),
          ],
        ),
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final List<DailyStat> stats;
  final bool showEveryLabel;
  const _ScoreChart({required this.stats, required this.showEveryLabel});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < stats.length; i++) FlSpot(i.toDouble(), stats[i].score),
    ];
    final labelStep = showEveryLabel ? 1 : (stats.length / 5).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 25,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0x22808080), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  reservedSize: 34,
                  getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: labelStep.toDouble().clamp(1, double.infinity),
                  reservedSize: 30,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                    final d = stats[i].day;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${d.month}/${d.day}',
                          style: Theme.of(context).textTheme.bodySmall),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                  final stat = stats[s.x.toInt()];
                  return LineTooltipItem(
                    '${stat.day.month}/${stat.day.day}\n${stat.score.toStringAsFixed(0)}%',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.teal,
                barWidth: 3,
                dotData: FlDotData(show: showEveryLabel),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.teal.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
