import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/challenge.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('ቻሌንጆች')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChallengeSheet(context),
        child: const Icon(Icons.add),
      ),
      body: app.activeChallenges.isEmpty
          ? const Center(child: Text('ገና ምንም ቻሌንጅ የለም'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: app.activeChallenges.length,
              itemBuilder: (context, i) {
                final c = app.activeChallenges[i];
                return Dismissible(
                  key: ValueKey(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, c.title),
                  onDismissed: (_) => context.read<AppProvider>().deleteChallenge(c.id),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showAddChallengeSheet(context, existing: c),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: c.progress,
                                minHeight: 8,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${c.completedDays}/${c.totalDays} ቀናት'),
                                Text('${c.daysRemaining} ቀናት ቀርተዋል',
                                    style: const TextStyle(color: AppColors.amber)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (c.completedDays > 0)
                                  TextButton(
                                    onPressed: () =>
                                        context.read<AppProvider>().undoChallengeDay(c),
                                    child: const Text('ተመለስ'),
                                  ),
                                TextButton(
                                  onPressed: () =>
                                      context.read<AppProvider>().logChallengeDay(c),
                                  child: const Text('ዛሬን ምልክት አድርግ'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ቻሌንጅ ይሰረዝ?'),
        content: Text('"$title" ይሰረዛል፣ ይህ ተግባር መልሶ ሊቀር አይችልም።'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('አይ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('አዎ፣ ሰርዝ')),
        ],
      ),
    );
    return result ?? false;
  }

  void _showAddChallengeSheet(BuildContext context, {Challenge? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final daysCtrl =
        TextEditingController(text: existing?.totalDays.toString() ?? '30');
    DateTime? alarmAt = existing?.alarmAt;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'ቻሌንጅ አርትዕ' : 'አዲስ ቻሌንጅ',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(ctx, existing.title);
                        if (confirmed && ctx.mounted) {
                          context.read<AppProvider>().deleteChallenge(existing.id);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'የቻሌንጅ ስም'),
              ),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'የቀናት ብዛት'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.alarm),
                label: Text(alarmAt == null ? 'አላርም ያዘጋጁ' : alarmAt.toString()),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time == null) return;
                  setState(() {
                    alarmAt = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute);
                  });
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  final days = int.tryParse(daysCtrl.text.trim()) ?? 30;
                  if (title.isEmpty) return;
                  if (isEdit) {
                    existing
                      ..title = title
                      ..totalDays = days;
                    context
                        .read<AppProvider>()
                        .updateChallenge(existing, newAlarmAt: alarmAt);
                  } else {
                    context
                        .read<AppProvider>()
                        .addChallenge(title, days, alarmAt: alarmAt);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('አስቀምጥ'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
