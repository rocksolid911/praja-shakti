abstract class GramSabhaState {}

class GramSabhaInitial extends GramSabhaState {}

class GramSabhaLoading extends GramSabhaState {}

class GramSabhaSession {
  final int id;
  final String title;
  final DateTime scheduledAt;
  final bool isActive;
  final String transcript;
  final List<GramSabhaIssue> issues;

  GramSabhaSession({
    required this.id, required this.title, required this.scheduledAt,
    required this.isActive, this.transcript = '', required this.issues,
  });

  factory GramSabhaSession.fromJson(Map<String, dynamic> json) => GramSabhaSession(
    id: json['id'],
    title: json['title'] ?? '',
    scheduledAt: DateTime.tryParse(json['scheduled_at'] ?? '') ?? DateTime.now(),
    isActive: json['is_active'] ?? false,
    transcript: json['transcript'] ?? '',
    issues: (json['issues'] as List? ?? []).map((i) => GramSabhaIssue.fromJson(i)).toList(),
  );
}

class GramSabhaIssue {
  final int id;
  final String title;
  final int voteCount;

  GramSabhaIssue({required this.id, required this.title, required this.voteCount});

  factory GramSabhaIssue.fromJson(Map<String, dynamic> json) => GramSabhaIssue(
    id: json['id'],
    title: json['title'] ?? '',
    voteCount: json['vote_count'] ?? 0,
  );
}

class GramSabhaLoaded extends GramSabhaState {
  final List<GramSabhaSession> sessions;
  GramSabhaLoaded(this.sessions);
}

class GramSabhaError extends GramSabhaState {
  final String message;
  GramSabhaError(this.message);
}

class GramSabhaSessionActive extends GramSabhaState {
  final GramSabhaSession session;
  GramSabhaSessionActive(this.session);
}
