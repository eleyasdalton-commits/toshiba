class Challenge {
  final String id;
  String title;
  DateTime startDate;
  int totalDays; // e.g. 30 for a "30-day challenge"
  int completedDays;
  DateTime? alarmAt;

  Challenge({
    required this.id,
    required this.title,
    required this.startDate,
    required this.totalDays,
    this.completedDays = 0,
    this.alarmAt,
  });

  DateTime get endDate => startDate.add(Duration(days: totalDays));

  int get daysRemaining {
    final remaining = endDate.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  double get progress => totalDays == 0 ? 0 : completedDays / totalDays;

  bool get isFinished => DateTime.now().isAfter(endDate);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        'totalDays': totalDays,
        'completedDays': completedDays,
        'alarmAt': alarmAt?.toIso8601String(),
      };

  factory Challenge.fromMap(Map<String, dynamic> map) => Challenge(
        id: map['id'] as String,
        title: map['title'] as String,
        startDate: DateTime.parse(map['startDate'] as String),
        totalDays: map['totalDays'] as int,
        completedDays: map['completedDays'] as int,
        alarmAt: map['alarmAt'] != null
            ? DateTime.parse(map['alarmAt'] as String)
            : null,
      );
}
