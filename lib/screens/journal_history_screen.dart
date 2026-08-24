import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/journal_entry.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'journal_screen.dart';

/// Lists the last 60 days of journal entries (only days that actually have
/// one) so the user can review or correct a past reflection. Tapping a row
/// reopens JournalScreen pre-loaded for that date.
class JournalHistoryScreen extends StatefulWidget {
  const JournalHistoryScreen({super.key});

  @override
  State<JournalHistoryScreen> createState() => _JournalHistoryScreenState();
}

class _JournalHistoryScreenState extends State<JournalHistoryScreen> {
  List<JournalEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await context.read<AppProvider>().getJournalHistory();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  static const _weekdays = ['ሰኞ', 'ማክሰ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሁድ'];

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('ያለፉ ውሎዎች')),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const Center(child: Text('ገና ምንም የተመዘገበ ውሎ የለም'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                          child: Text('${e.ratingSum}',
                              style: const TextStyle(
                                  color: AppColors.teal, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                            '${e.date.year}/${e.date.month}/${e.date.day} · ${_weekdays[e.date.weekday - 1]}'),
                        subtitle: Text(
                          e.reflection.isEmpty ? 'ምንም ማስታወሻ የለም' : e.reflection,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => JournalScreen(date: e.date)),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
