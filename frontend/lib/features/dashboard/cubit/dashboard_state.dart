import '../../../core/models/project.dart';

class PriorityCluster {
  final int id;
  final String category;
  final int reportCount;
  final int upvoteCount;
  final double totalScore;
  final double communityScore;
  final double dataScore;
  final double urgencyScore;
  final String justification;

  PriorityCluster({
    required this.id, required this.category,
    required this.reportCount, required this.upvoteCount,
    required this.totalScore, required this.communityScore,
    required this.dataScore, required this.urgencyScore,
    required this.justification,
  });

  factory PriorityCluster.fromJson(Map<String, dynamic> json) {
    final score = json['priority_score'];
    return PriorityCluster(
      id: json['id'],
      category: json['category'] ?? '',
      reportCount: json['report_count'] ?? 0,
      upvoteCount: json['upvote_count'] ?? 0,
      totalScore: (score?['total_score'] ?? 0).toDouble(),
      communityScore: (score?['community_score'] ?? 0).toDouble(),
      dataScore: (score?['data_score'] ?? 0).toDouble(),
      urgencyScore: (score?['urgency_score'] ?? 0).toDouble(),
      justification: score?['justification'] ?? '',
    );
  }
}

class FundStatus {
  final String category;
  final int allocatedInr;
  final int spentInr;
  final double utilizationPct;

  FundStatus({required this.category, required this.allocatedInr,
      required this.spentInr, required this.utilizationPct});

  factory FundStatus.fromJson(Map<String, dynamic> json) => FundStatus(
    category: json['category'] ?? '',
    allocatedInr: json['allocated_inr'] ?? 0,
    spentInr: json['spent_inr'] ?? 0,
    utilizationPct: (json['utilization_pct'] ?? 0).toDouble(),
  );
}

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<PriorityCluster> priorities;
  final List<Project> activeProjects;
  final List<FundStatus> fundStatus;
  final int totalReports;
  final int completedProjects;
  final Project? lastAdoptedProject;

  DashboardLoaded({
    required this.priorities,
    required this.activeProjects,
    required this.fundStatus,
    required this.totalReports,
    required this.completedProjects,
    this.lastAdoptedProject,
  });

  DashboardLoaded copyWith({
    List<PriorityCluster>? priorities,
    List<Project>? activeProjects,
    List<FundStatus>? fundStatus,
    int? totalReports,
    int? completedProjects,
    Project? lastAdoptedProject,
  }) {
    return DashboardLoaded(
      priorities: priorities ?? this.priorities,
      activeProjects: activeProjects ?? this.activeProjects,
      fundStatus: fundStatus ?? this.fundStatus,
      totalReports: totalReports ?? this.totalReports,
      completedProjects: completedProjects ?? this.completedProjects,
      lastAdoptedProject: lastAdoptedProject ?? this.lastAdoptedProject,
    );
  }
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}
