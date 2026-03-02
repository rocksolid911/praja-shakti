import '../../../core/models/village.dart';
import '../../../core/models/report.dart';
import '../../../core/models/project.dart';

class ReportCluster {
  final int id;
  final String category;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final int reportCount;
  final int upvoteCount;
  final double? priorityScore;

  ReportCluster({
    required this.id, required this.category,
    required this.latitude, required this.longitude,
    required this.radiusKm, required this.reportCount,
    required this.upvoteCount, this.priorityScore,
  });

  factory ReportCluster.fromJson(Map<String, dynamic> json) {
    double lat = 0, lng = 0;
    final geo = json['centroid_geojson'];
    if (geo is Map) {
      final coords = geo['coordinates'] as List?;
      if (coords != null && coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }
    return ReportCluster(
      id: json['id'],
      category: json['category'] ?? '',
      latitude: lat, longitude: lng,
      radiusKm: (json['radius_km'] ?? 0.5).toDouble(),
      reportCount: json['report_count'] ?? 0,
      upvoteCount: json['upvote_count'] ?? 0,
      priorityScore: json['priority_score']?.toDouble(),
    );
  }
}

abstract class MapState {}

class MapInitial extends MapState {}

class MapLoading extends MapState {}

class MapLoaded extends MapState {
  final Village? selectedVillage;
  final List<Report> reports;
  final List<ReportCluster> clusters;
  final List<Project> projects;
  // Layer data
  final List<Map<String, dynamic>> infrastructure;   // [{infra_type, name, lat, lng}]
  final List<Map<String, dynamic>> heatmapPoints;    // [{lat, lng, weight, category}]
  final Map<String, dynamic> demographics;            // {population, households, ...}
  final Map<String, dynamic> fundStatus;              // {fund_available_inr, panchayat_name}
  // Layer toggles
  final bool showReports;
  final bool showSatellite;
  final bool showInfrastructure;
  final bool showHeatmap;
  final bool showProjects;
  final bool showFundStatus;
  final bool showDemographics;

  MapLoaded({
    this.selectedVillage,
    this.reports = const [],
    this.clusters = const [],
    this.projects = const [],
    this.infrastructure = const [],
    this.heatmapPoints = const [],
    this.demographics = const {},
    this.fundStatus = const {},
    this.showReports = true,
    this.showSatellite = false,
    this.showInfrastructure = false,
    this.showHeatmap = false,
    this.showProjects = true,
    this.showFundStatus = false,
    this.showDemographics = false,
  });

  MapLoaded copyWith({
    Village? selectedVillage,
    List<Report>? reports,
    List<ReportCluster>? clusters,
    List<Project>? projects,
    List<Map<String, dynamic>>? infrastructure,
    List<Map<String, dynamic>>? heatmapPoints,
    Map<String, dynamic>? demographics,
    Map<String, dynamic>? fundStatus,
    bool? showReports,
    bool? showSatellite,
    bool? showInfrastructure,
    bool? showHeatmap,
    bool? showProjects,
    bool? showFundStatus,
    bool? showDemographics,
  }) {
    return MapLoaded(
      selectedVillage: selectedVillage ?? this.selectedVillage,
      reports: reports ?? this.reports,
      clusters: clusters ?? this.clusters,
      projects: projects ?? this.projects,
      infrastructure: infrastructure ?? this.infrastructure,
      heatmapPoints: heatmapPoints ?? this.heatmapPoints,
      demographics: demographics ?? this.demographics,
      fundStatus: fundStatus ?? this.fundStatus,
      showReports: showReports ?? this.showReports,
      showSatellite: showSatellite ?? this.showSatellite,
      showInfrastructure: showInfrastructure ?? this.showInfrastructure,
      showHeatmap: showHeatmap ?? this.showHeatmap,
      showProjects: showProjects ?? this.showProjects,
      showFundStatus: showFundStatus ?? this.showFundStatus,
      showDemographics: showDemographics ?? this.showDemographics,
    );
  }
}

class MapError extends MapState {
  final String message;
  MapError(this.message);
}
