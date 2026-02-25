import '../../../core/models/report.dart';

abstract class ReportState {}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportRecording extends ReportState {
  final Duration duration;
  ReportRecording(this.duration);
}

class ReportSubmitting extends ReportState {}

class ReportSubmitted extends ReportState {
  final Report report;
  ReportSubmitted(this.report);
}

class ReportLoaded extends ReportState {
  final Report report;
  ReportLoaded(this.report);
}

class ReportError extends ReportState {
  final String message;
  ReportError(this.message);
}
