import '../../../core/models/report.dart';

abstract class CommunityState {}

class CommunityInitial extends CommunityState {}

class CommunityLoading extends CommunityState {}

class CommunityLoaded extends CommunityState {
  final List<Report> reports;
  final bool hasMore;
  final String? activeFilter;

  CommunityLoaded({required this.reports, this.hasMore = false, this.activeFilter});

  CommunityLoaded copyWith({List<Report>? reports, bool? hasMore, String? activeFilter}) {
    return CommunityLoaded(
      reports: reports ?? this.reports,
      hasMore: hasMore ?? this.hasMore,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class CommunityError extends CommunityState {
  final String message;
  CommunityError(this.message);
}
