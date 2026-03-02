abstract class SchemeState {}

class SchemeInitial extends SchemeState {}

class SchemeLoading extends SchemeState {}

class SchemeQueryResult extends SchemeState {
  final String query;
  final String answer;
  final List<Map<String, String>> sources;
  final List<SchemeMessage> history;

  SchemeQueryResult({required this.query, required this.answer, required this.sources, required this.history});
}

class SchemeError extends SchemeState {
  final String message;
  SchemeError(this.message);
}

class SchemeMessage {
  final String text;
  final bool isUser;
  final List<Map<String, String>> sources;

  SchemeMessage({required this.text, required this.isUser, this.sources = const []});
}
