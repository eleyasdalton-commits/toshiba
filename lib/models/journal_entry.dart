/// The SRS splits each day into three segments — morning, afternoon,
/// evening — each rated on a 1–5 scale, plus a free-text reflection.
class JournalEntry {
  final String id;
  final DateTime date; // stored as the day only (time truncated)
  int morningRating; // 1-5
  int afternoonRating; // 1-5
  int eveningRating; // 1-5
  String reflection;

  JournalEntry({
    required this.id,
    required this.date,
    this.morningRating = 0,
    this.afternoonRating = 0,
    this.eveningRating = 0,
    this.reflection = '',
  });

  /// Sum used directly by the daily score formula (max 15 = 3 segments × 5).
  int get ratingSum => morningRating + afternoonRating + eveningRating;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'morningRating': morningRating,
        'afternoonRating': afternoonRating,
        'eveningRating': eveningRating,
        'reflection': reflection,
      };

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        morningRating: map['morningRating'] as int,
        afternoonRating: map['afternoonRating'] as int,
        eveningRating: map['eveningRating'] as int,
        reflection: map['reflection'] as String? ?? '',
      );
}
