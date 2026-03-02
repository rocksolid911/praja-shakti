import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';
import 'project_state.dart';

class ProjectCubit extends Cubit<ProjectState> {
  final ApiClient _api;

  ProjectCubit(this._api) : super(ProjectInitial());

  Future<void> loadProjects({int villageId = 1, String? status}) async {
    emit(ProjectLoading());
    try {
      final params = <String, dynamic>{
        'village': villageId,
        if (status != null) 'status': status,
      };
      final resp = await _api.get('/projects/', queryParameters: params);
      final data = resp.data;
      final results = (data is Map ? (data['results'] ?? []) : data) as List;
      emit(ProjectsLoaded(
        projects: results.map((p) => Project.fromJson(p)).toList(),
        activeFilter: status,
      ));
    } catch (e) {
      emit(ProjectError('Failed to load projects'));
    }
  }

  Future<void> loadProjectDetail(int projectId) async {
    emit(ProjectLoading());
    try {
      final resp = await _api.get('/projects/$projectId/');
      emit(ProjectDetailLoaded(Project.fromJson(resp.data)));
    } catch (e) {
      emit(ProjectError('Failed to load project details'));
    }
  }

  Future<void> adoptProject(int clusterId, int recommendationIndex) async {
    emit(ProjectLoading());
    try {
      final resp = await _api.post('/projects/adopt/', data: {
        'cluster_id': clusterId,
        'recommendation_index': recommendationIndex,
      });
      emit(ProjectAdopted(Project.fromJson(resp.data)));
    } catch (e) {
      emit(ProjectError('Failed to adopt project'));
    }
  }

  Future<void> updateStatus(int projectId, String status) async {
    try {
      await _api.patch('/projects/$projectId/update_status/', data: {'status': status});
      await loadProjectDetail(projectId);
    } catch (e) {
      emit(ProjectError('Failed to update status'));
    }
  }

  Future<void> rateProject(int projectId, int rating, String review) async {
    try {
      await _api.post('/projects/$projectId/rating/', data: {
        'rating': rating,
        'review': review,
      });
      await loadProjectDetail(projectId);
    } catch (e) {
      emit(ProjectError('Failed to submit rating'));
    }
  }
}
