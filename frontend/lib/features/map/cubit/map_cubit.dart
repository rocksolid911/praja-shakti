import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/village.dart';
import '../../../core/models/report.dart';
import '../../../core/models/project.dart';
import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  final ApiClient _api;
  int? _currentVillageId;

  MapCubit(this._api) : super(MapInitial());

  Future<void> loadVillageData(int villageId) async {
    _currentVillageId = villageId;
    emit(MapLoading());
    try {
      // Load all layers in parallel
      final results = await Future.wait([
        _api.get('/reports/', queryParameters: {'village': villageId, 'page_size': 100}),
        _api.get('/reports/clusters/', queryParameters: {'village': villageId}),
        _api.get('/projects/', queryParameters: {'village': villageId}),
        _api.get('/villages/$villageId/'),
        _api.get('/map/layers/', queryParameters: {
          'village': villageId,
          'layers': 'infra,heatmap,demographics,fund_status',
        }),
      ]);

      final reportsData = results[0].data;
      final clustersData = results[1].data;
      final projectsData = results[2].data;
      final villageData = results[3].data;
      final layersData = results[4].data as Map<String, dynamic>? ?? {};

      final reports = ((reportsData is Map ? reportsData['results'] : reportsData) as List? ?? [])
          .map((r) => Report.fromJson(r)).toList();

      // Clusters endpoint returns a GeoJSON FeatureCollection
      List<dynamic> rawClusters;
      if (clustersData is Map && clustersData['features'] != null) {
        rawClusters = clustersData['features'] as List;
      } else if (clustersData is List) {
        rawClusters = clustersData;
      } else {
        rawClusters = (clustersData['results'] ?? []) as List;
      }
      final clusters = rawClusters.map((f) {
        if (f is Map && f['properties'] != null) {
          final props = Map<String, dynamic>.from(f['properties'] as Map);
          props['centroid_geojson'] = f['geometry'];
          props['priority_score'] = props['community_priority_score'];
          return ReportCluster.fromJson(props);
        }
        return ReportCluster.fromJson(f as Map<String, dynamic>);
      }).toList();
      final projects = ((projectsData is Map ? projectsData['results'] : projectsData) as List? ?? [])
          .map((p) => Project.fromJson(p)).toList();
      final village = Village.fromJson(villageData);

      // Parse infrastructure layer
      final infraFeatures = (layersData['infrastructure']?['features'] as List? ?? []);
      final infrastructure = infraFeatures.map((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final coords = (f['geometry']?['coordinates'] as List?) ?? [];
        return <String, dynamic>{
          'type': props['infra_type'] ?? '',
          'name': props['name'] ?? '',
          'lat': coords.length >= 2 ? (coords[1] as num).toDouble() : 0.0,
          'lng': coords.length >= 2 ? (coords[0] as num).toDouble() : 0.0,
        };
      }).where((i) => i['lat'] != 0.0).toList();

      // Parse heatmap layer
      final heatFeatures = (layersData['heatmap']?['features'] as List? ?? []);
      final heatmapPoints = heatFeatures.map((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final coords = (f['geometry']?['coordinates'] as List?) ?? [];
        return <String, dynamic>{
          'lat': coords.length >= 2 ? (coords[1] as num).toDouble() : 0.0,
          'lng': coords.length >= 2 ? (coords[0] as num).toDouble() : 0.0,
          'weight': ((props['weight'] ?? 0) as num).toDouble() / 100.0,
          'category': props['category'] ?? '',
        };
      }).where((h) => h['lat'] != 0.0).toList();

      // Parse demographics and fund status
      final demographics = (layersData['demographics'] as Map<String, dynamic>?) ?? {};
      final fundStatus = (layersData['fund_status'] as Map<String, dynamic>?) ?? {};

      emit(MapLoaded(
        selectedVillage: village,
        reports: reports,
        clusters: clusters,
        projects: projects,
        infrastructure: infrastructure,
        heatmapPoints: heatmapPoints,
        demographics: demographics,
        fundStatus: fundStatus,
        showReports: true,
        showProjects: true,
      ));
    } catch (e) {
      emit(MapError('Failed to load village data: $e'));
    }
  }

  void toggleLayer(String layer) {
    final current = state;
    if (current is! MapLoaded) return;
    switch (layer) {
      case 'reports':
        emit(current.copyWith(showReports: !current.showReports));
      case 'satellite':
        emit(current.copyWith(showSatellite: !current.showSatellite));
      case 'infrastructure':
        emit(current.copyWith(showInfrastructure: !current.showInfrastructure));
      case 'heatmap':
        emit(current.copyWith(showHeatmap: !current.showHeatmap));
      case 'projects':
        emit(current.copyWith(showProjects: !current.showProjects));
      case 'fund_status':
        emit(current.copyWith(showFundStatus: !current.showFundStatus));
      case 'demographics':
        emit(current.copyWith(showDemographics: !current.showDemographics));
    }
  }

  Future<void> refresh() async {
    if (_currentVillageId != null) {
      await loadVillageData(_currentVillageId!);
    }
  }
}
