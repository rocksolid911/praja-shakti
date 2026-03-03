import 'dart:typed_data';
import 'package:dio/dio.dart';
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
        'page': 1,
      };
      final resp = await _api.get('/projects/', queryParameters: params);
      final data = resp.data;
      final results = (data is Map ? (data['results'] ?? data) : data) as List;
      final hasMore = data is Map && data['next'] != null;
      emit(ProjectsLoaded(
        projects: results.map((p) => Project.fromJson(p)).toList(),
        activeFilter: status,
        hasMore: hasMore,
        currentPage: 1,
      ));
    } catch (e) {
      emit(ProjectError('Failed to load projects'));
    }
  }

  Future<void> loadMoreProjects({int villageId = 1}) async {
    final current = state;
    if (current is! ProjectsLoaded || !current.hasMore || current.isLoadingMore) return;
    emit(ProjectsLoaded(
      projects: current.projects,
      activeFilter: current.activeFilter,
      hasMore: current.hasMore,
      isLoadingMore: true,
      currentPage: current.currentPage,
    ));
    try {
      final nextPage = current.currentPage + 1;
      final params = <String, dynamic>{
        'village': villageId,
        if (current.activeFilter != null) 'status': current.activeFilter!,
        'page': nextPage,
      };
      final resp = await _api.get('/projects/', queryParameters: params);
      final data = resp.data;
      final newResults = (data is Map ? (data['results'] ?? []) : data) as List;
      emit(ProjectsLoaded(
        projects: [
          ...current.projects,
          ...newResults.map((p) => Project.fromJson(p)),
        ],
        activeFilter: current.activeFilter,
        hasMore: data is Map && data['next'] != null,
        currentPage: nextPage,
      ));
    } catch (e) {
      emit(ProjectError('Failed to load more projects'));
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

  Future<void> uploadPhoto(
    int projectId, {
    required Uint8List bytes,
    required String filename,
    String caption = '',
    bool isDelayReport = false,
  }) async {
    try {
      final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType('image', ext == 'png' ? 'png' : 'jpeg'),
        ),
        'caption': caption,
        'is_delay_report': isDelayReport.toString(),
      });
      await _api.postFormData('/projects/$projectId/photos/', formData);
      await loadProjectDetail(projectId);
    } catch (e) {
      emit(ProjectError('Failed to upload photo'));
    }
  }
}
