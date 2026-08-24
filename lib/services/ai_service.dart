import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import 'score_service.dart';

/// Facade the UI calls into. Internally picks the online Gemini-backed
/// coach when a network is available, and falls back to a fully offline
/// rule-based heuristic otherwise — exactly the split the SRS specifies
/// in section 2 ("Online: Gemini API / Offline: Rule-Based Analytics").
class AIService {
  /// Set this from your own secure config (e.g. --dart-define) before
  /// shipping. Never hard-code a real key in source control.
  static const String _geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<String> getDailyFeedback({
    required List<AppTask> tasks,
    required List<Habit> habits,
    required JournalEntry? journal,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);

    if (isOnline && _geminiApiKey.isNotEmpty) {
      try {
        return await _onlineFeedback(tasks: tasks, habits: habits, journal: journal);
      } catch (_) {
        // Network/API failure → silently fall back to offline heuristic
        // rather than surfacing an error to the user.
        return _offlineFeedback(tasks: tasks, habits: habits, journal: journal);
      }
    }
    return _offlineFeedback(tasks: tasks, habits: habits, journal: journal);
  }

  // ---------------- Online: Gemini API ----------------
  Future<String> _onlineFeedback({
    required List<AppTask> tasks,
    required List<Habit> habits,
    required JournalEntry? journal,
  }) async {
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final completedHabits = habits.where((h) => h.completedToday).length;
    final score = ScoreService.dailyScore(tasks: tasks, habits: habits, journal: journal);

    final prompt = '''
You are a supportive daily productivity coach. In under 60 words, in Amharic,
give the user one encouraging observation and one concrete suggestion for
tomorrow, based on:
- Tasks completed: $completedTasks / ${tasks.length}
- Habits completed: $completedHabits / ${habits.length}
- Reflection ratings (morning/afternoon/evening, 1-5): ${journal?.morningRating ?? 0}/${journal?.afternoonRating ?? 0}/${journal?.eveningRating ?? 0}
- Daily score: ${score.toStringAsFixed(0)}%
''';

    final response = await http.post(
      Uri.parse('$_geminiEndpoint?key=$_geminiApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    return (text as String?)?.trim() ?? _offlineFeedback(tasks: tasks, habits: habits, journal: journal);
  }

  // ---------------- Offline: rule-based heuristic ----------------
  String _offlineFeedback({
    required List<AppTask> tasks,
    required List<Habit> habits,
    required JournalEntry? journal,
  }) {
    final score = ScoreService.dailyScore(tasks: tasks, habits: habits, journal: journal);
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final incompleteHigh =
        tasks.where((t) => !t.isCompleted && t.priority == TaskPriority.high).length;
    final missedHabits = habits.where((h) => !h.completedToday).length;

    final lines = <String>[];

    if (score >= 80) {
      lines.add('በጣም ጥሩ ቀን አሳልፈዋል! ውጤትዎ ${score.toStringAsFixed(0)}% ነው።');
    } else if (score >= 50) {
      lines.add('መልካም እድገት እያደረጉ ነው። ውጤትዎ ${score.toStringAsFixed(0)}% ነው።');
    } else if (tasks.isEmpty && habits.isEmpty) {
      lines.add('ዛሬ ምንም ያልተመዘገበ ተግባር የለም። ትንሽ እቅድ ማስያዝ ይሞክሩ።');
    } else {
      lines.add('ቀኑ ፈታኝ ነበር። ውጤትዎ ${score.toStringAsFixed(0)}% ነው፣ ነገ የተሻለ ማድረግ ይችላሉ።');
    }

    if (incompleteHigh > 0) {
      lines.add('$incompleteHigh ከፍተኛ ቅድሚያ የሚሰጣቸው ተግባራት ገና አልተጠናቀቁም — ነገ ጠዋት ቅድሚያ ይስጧቸው።');
    }
    if (missedHabits > 0 && habits.isNotEmpty) {
      lines.add('$missedHabits ልምዶች ዛሬ አልተከናወኑም። ትንሽ ማሳሰቢያ ማዘጋጀት ይረዳል።');
    }
    if (completedTasks > 0 && incompleteHigh == 0 && missedHabits == 0) {
      lines.add('ጥሩ ወጥነት እያሳዩ ነው — ይቀጥሉበት!');
    }

    return lines.join(' ');
  }
}
