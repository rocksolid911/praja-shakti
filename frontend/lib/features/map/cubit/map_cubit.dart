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
        _api.get('/geo/villages/$villageId/'),
      ]);

      final reportsData = results[0].data;
      final clustersData = results[1].data;
      final projectsData = results[2].data;
      final villageData = results[3].data;

      final reports = ((reportsData is Map ? reportsData['results'] : reportsData) as List? ?? [])
          .map((r) => Report.fromJson(r)).toList();
      final clusters = ((clustersData is List ? clustersData : (clustersData['results'] ?? [])) as List)
          .map((c) => ReportCluster.fromJson(c)).toList();
      final projects = ((projectsData is Map ? projectsData['results'] : projectsData) as List? ?? [])
          .map((p) => Project.fromJson(p)).toList();
      final village = Village.fromJson(villageData);

      emit(MapLoaded(
        selectedVillage: village,
        reports: reports,
        clusters: clusters,
        projects: projects,
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
