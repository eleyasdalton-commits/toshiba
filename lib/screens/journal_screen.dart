import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/journal_entry.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'journal_history_screen.dart';

class JournalScreen extends StatefulWidget {
  /// Day to view/edit. Defaults to today. Pass a past date (e.g. from
  /// [JournalHistoryScreen]) to fill in or correct an earlier entry.
  final DateTime? date;
  const JournalScreen({super.key, this.date});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late DateTime day;
  late bool isToday;
  int morning = 0;
  int afternoon = 0;
  int evening = 0;
  final reflectionCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final requested = widget.date ?? now;
    day = DateTime(requested.year, requested.month, requested.day);
    isToday = day == DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    final JournalEntry? j =
        isToday ? app.todayJournal : await app.getJournalForDate(day);
    if (!mounted) return;
    setState(() {
      morning = j?.morningRating ?? 0;
      afternoon = j?.afternoonRating ?? 0;
      evening = j?.eveningRating ?? 0;
      reflectionCtrl.text = j?.reflection ?? '';
      _loading = false;
    });
  }

  Widget _ratingRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label)),
        ...List.generate(5, (i) {
          final star = i + 1;
          return IconButton(
            icon: Icon(
              star <= value ? Icons.star : Icons.star_border,
              color: AppColors.amber,
            ),
            onPressed: () => onChanged(star),
          );
        }),
      ],
    );
  }

  String _formatDay(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isToday ? 'የእለት ውሎ' : 'የ${_formatDay(day)} ውሎ'),
        actions: [
          if (isToday)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'ያለፉ ቀናት',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JournalHistoryScreen())),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('የ3 ክፍለ-ጊዜ ምዘና', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _ratingRow('ጠዋት', morning, (v) => setState(() => morning = v)),
                  _ratingRow('ከሰዓት', afternoon, (v) => setState(() => afternoon = v)),
                  _ratingRow('ማታ', evening, (v) => setState(() => evening = v)),
                  const SizedBox(height: 16),
                  Text('የቀኑ ማጠቃለያ', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reflectionCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'ቀኑ እንዴት ነበር?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<AppProvider>().saveJournalForDate(
                            date: day,
                            morning: morning,
                            afternoon: afternoon,
                            evening: evening,
                            reflection: reflectionCtrl.text.trim(),
                          );
                      Navigator.pop(context);
                    },
                    child: const Text('አስቀምጥ'),
                  ),
                ],
              ),
            ),
    );
  }
}
