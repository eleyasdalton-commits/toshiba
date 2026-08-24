import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class HabitScreen extends StatelessWidget {
  const HabitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('ልምዶች')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHabitSheet(context),
        child: const Icon(Icons.add),
      ),
      body: app.habits.isEmpty
          ? const Center(child: Text('ገና ምንም ልምድ አልተመዘገበም'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: app.habits.length,
              itemBuilder: (context, i) {
                final h = app.habits[i];
                return Dismissible(
                  key: ValueKey(h.id),
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
                  confirmDismiss: (_) => _confirmDelete(context, h.name),
                  onDismissed: (_) => context.read<AppProvider>().deleteHabit(h.id),
                  child: Card(
                    child: ListTile(
                      onTap: () => _showAddHabitSheet(context, existing: h),
                      title: Text(h.name),
                      subtitle: Text('ምርጥ ተከታታይ: ${h.bestStreak} ቀናት'),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.amber.withValues(alpha: 0.15),
                        child: Text('${h.currentStreak}',
                            style: const TextStyle(
                                color: AppColors.amber, fontWeight: FontWeight.bold)),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          h.completedToday
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: h.completedToday ? AppColors.teal : null,
                        ),
                        onPressed: () => h.completedToday
                            ? app.undoHabitToday(h)
                            : app.completeHabitToday(h),
                        tooltip: h.completedToday ? 'ዛሬ ምልክት አንሳ' : 'ዛሬ ምልክት አድርግ',
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ልምድ ይሰረዝ?'),
        content: Text('"$name" ከመላ ታሪኩ ጋር ይሰረዛል፣ ይህ ተግባር መልሶ ሊቀር አይችልም።'),
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

  void _showAddHabitSheet(BuildContext context, {Habit? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
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
                  Text(isEdit ? 'ልምድ አርትዕ' : 'አዲስ ልምድ',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(ctx, existing.name);
                        if (confirmed && ctx.mounted) {
                          context.read<AppProvider>().deleteHabit(existing.id);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'የልምድ ስም'),
              ),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'ምድብ (አማራጭ)'),
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
                  if (nameCtrl.text.trim().isEmpty) return;
                  final category =
                      categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim();
                  if (isEdit) {
                    existing
                      ..name = nameCtrl.text.trim()
                      ..category = category;
                    context.read<AppProvider>().updateHabit(existing, newAlarmAt: alarmAt);
                  } else {
                    context.read<AppProvider>().addHabit(
                          nameCtrl.text.trim(),
                          category: category,
                          alarmAt: alarmAt,
                        );
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
