import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('ተግባራት')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context),
        child: const Icon(Icons.add),
      ),
      body: app.todayTasks.isEmpty
          ? const Center(child: Text('ዛሬ ምንም ተግባር አልተመዘገበም'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: app.todayTasks.length,
              itemBuilder: (context, i) {
                final t = app.todayTasks[i];
                return Dismissible(
                  key: ValueKey(t.id),
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
                  confirmDismiss: (_) => _confirmDelete(context, t.title),
                  onDismissed: (_) => context.read<AppProvider>().deleteTask(t.id),
                  child: Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: t.isCompleted,
                        onChanged: (_) => app.toggleTaskCompleted(t),
                      ),
                      title: Text(
                        t.title,
                        style: TextStyle(
                          decoration:
                              t.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text('${t.category} · ${_priorityLabel(t.priority)}'),
                      trailing: _priorityDot(t.priority),
                      onTap: () => _showAddTaskSheet(context, existing: t),
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
        title: const Text('ተግባር ይሰረዝ?'),
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

  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.high => 'ከፍተኛ',
        TaskPriority.medium => 'መካከለኛ',
        TaskPriority.low => 'ዝቅተኛ',
      };

  Widget _priorityDot(TaskPriority p) {
    final color = switch (p) {
      TaskPriority.high => Colors.redAccent,
      TaskPriority.medium => AppColors.amber,
      TaskPriority.low => AppColors.teal,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  void _showAddTaskSheet(BuildContext context, {AppTask? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    TaskPriority priority = existing?.priority ?? TaskPriority.medium;
    TaskScope scope = existing?.scope ?? TaskScope.daily;
    DateTime dueAt = existing?.dueAt ?? DateTime.now();
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
                  Text(isEdit ? 'ተግባር አርትዕ' : 'አዲስ ተግባር',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final confirmed = await _confirmDelete(ctx, existing.title);
                        if (confirmed && ctx.mounted) {
                          context.read<AppProvider>().deleteTask(existing.id);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'ርዕስ'),
              ),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'ምድብ'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TaskPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'ቅደም ተከተል'),
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() => priority = v ?? priority),
              ),
              DropdownButtonFormField<TaskScope>(
                initialValue: scope,
                decoration: const InputDecoration(labelText: 'ወሰን (ሰዓት/ቀን/ሳምንት...)'),
                items: TaskScope.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setState(() => scope = v ?? scope),
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
                  if (titleCtrl.text.trim().isEmpty) return;
                  final category = categoryCtrl.text.trim().isEmpty
                      ? 'አጠቃላይ'
                      : categoryCtrl.text.trim();
                  if (isEdit) {
                    existing
                      ..title = titleCtrl.text.trim()
                      ..category = category
                      ..priority = priority
                      ..scope = scope
                      ..dueAt = dueAt;
                    context.read<AppProvider>().updateTask(existing, newAlarmAt: alarmAt);
                  } else {
                    context.read<AppProvider>().addTask(
                          title: titleCtrl.text.trim(),
                          category: category,
                          priority: priority,
                          scope: scope,
                          dueAt: dueAt,
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
