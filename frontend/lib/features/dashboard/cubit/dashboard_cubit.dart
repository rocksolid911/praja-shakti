import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final ApiClient _api;

  DashboardCubit(this._api) : super(DashboardInitial());

  Future<void> loadDashboard({int villageId = 1}) async {
    emit(DashboardLoading());
    try {
      final results = await Future.wait([
        _api.get('/ai/priorities/', queryParameters: {'village': villageId}),
        _api.get('/projects/', queryParameters: {'village': villageId, 'status': 'in_progress'}),
        _api.get('/dashboard/fund-status/', queryParameters: {'panchayat': 1}),
      ]);

      final prioritiesData = results[0].data;
      final projectsData = results[1].data;
      final fundData = results[2].data;

      final rawPriorities = (prioritiesData is List ? prioritiesData : (prioritiesData['results'] ?? [])) as List;
      final rawProjects = (projectsData is Map ? (projectsData['results'] ?? []) : projectsData) as List;
      final rawFund = (fundData is List ? fundData : (fundData['by_category'] ?? [])) as List;

      emit(DashboardLoaded(
        priorities: rawPriorities.map((p) => PriorityCluster.fromJson(p)).toList(),
        activeProjects: rawProjects.map((p) => Project.fromJson(p)).toList(),
        fundStatus: rawFund.map((f) => FundStatus.fromJson(f)).toList(),
        totalReports: (prioritiesData is Map ? prioritiesData['total_reports'] : 0) ?? 0,
        completedProjects: 0,
      ));
    } catch (e) {
      emit(DashboardError('Failed to load dashboard: $e'));
    }
  }

  Future<void> adoptProject(int clusterId, int recommendationIndex) async {
    // Capture the current loaded state so we can restore it on failure instead
    // of blanking the screen with DashboardError.
    final previousState = state;

    try {
      final resp = await _api.post('/projects/adopt/', data: {
        'cluster_id': clusterId,
        'recommendation_index': recommendationIndex,
      });

      // Parse the adopted project from the response
      Project? adoptedProject;
      try {
        if (resp.data is Map && resp.data['id'] != null) {
          adoptedProject = Project.fromJson(resp.data as Map<String, dynamic>);
        }
      } catch (_) {}

      // Reload dashboard to reflect new project status
      await loadDashboard();

      // Surface the adopted project for the proposal dialog
      if (adoptedProject != null && state is DashboardLoaded) {
        emit((state as DashboardLoaded).copyWith(lastAdoptedProject: adoptedProject));
      }
    } catch (e) {
      // Restore previous state instead of showing a blank/error screen.
      // The snackbar already informed the user; a silent dashboard refresh is cleaner.
      if (previousState is DashboardLoaded) {
        emit(previousState);
      }
      // Attempt a quiet reload so the data is fresh
      try {
        await loadDashboard();
      } catch (_) {}
    }
  }
}
