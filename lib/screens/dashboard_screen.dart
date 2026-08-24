import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'todo_screen.dart';
import 'habit_screen.dart';
import 'challenge_screen.dart';
import 'journal_screen.dart';
import 'stats_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        if (app.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('ዳሽቦርድ'),
            actions: [
              Consumer<ThemeProvider>(
                builder: (context, theme, _) => IconButton(
                  icon: Icon(theme.icon),
                  tooltip: theme.label,
                  onPressed: theme.cycle,
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: app.loadToday,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScoreCard(score: app.dailyScore),
                const SizedBox(height: 14),
                _AiFeedbackCard(feedback: app.aiFeedback),
                const SizedBox(height: 14),
                _SegmentRatingsCard(),
                const SizedBox(height: 14),
                _ChallengesRow(),
                const SizedBox(height: 14),
                _QuickNav(),
                const SizedBox(height: 8),
                _StatsNavCard(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final double score;
  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('የዛሬ እድገት', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 12,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
            const SizedBox(height: 8),
            Text('${score.toStringAsFixed(0)}%',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.teal, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _AiFeedbackCard extends StatelessWidget {
  final String feedback;
  const _AiFeedbackCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feedback.isEmpty ? 'የኤአይ ትንተና በመዘጋጀት ላይ...' : feedback,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentRatingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final j = app.todayJournal;
    Widget seg(String label, int rating) => Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text('$rating/5',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.teal)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const JournalScreen())),
          child: Row(
            children: [
              seg('ጠዋት', j?.morningRating ?? 0),
              seg('ከሰዓት', j?.afternoonRating ?? 0),
              seg('ማታ', j?.eveningRating ?? 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.activeChallenges.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: app.activeChallenges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = app.activeChallenges[i];
          return Card(
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text('${c.daysRemaining} ቀናት ቀርተዋል',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.amber)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget tile(String label, IconData icon, Widget screen) => Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => screen)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Icon(icon, color: AppColors.teal),
                    const SizedBox(height: 6),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        );

    return Row(
      children: [
        tile('ተግባራት', Icons.check_circle_outline, const TodoScreen()),
        const SizedBox(width: 8),
        tile('ልምዶች', Icons.local_fire_department_outlined, const HabitScreen()),
        const SizedBox(width: 8),
        tile('ቻሌንጆች', Icons.flag_outlined, const ChallengeScreen()),
      ],
    );
  }
}

class _StatsNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.show_chart, color: AppColors.teal),
        title: const Text('ስታትስቲክስ (ሳምንታዊ/ወርሃዊ)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StatsScreen())),
      ),
    );
  }
}
