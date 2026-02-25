import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import 'community_state.dart';

class CommunityCubit extends Cubit<CommunityState> {
  final ApiClient _api;
  int _page = 1;
  int? _villageId;

  CommunityCubit(this._api) : super(CommunityInitial());

  Future<void> loadReports({int villageId = 1, String? category}) async {
    _villageId = villageId;
    _page = 1;
    emit(CommunityLoading());
    try {
      final params = <String, dynamic>{
        'village': villageId,
        'ordering': '-vote_count',
        if (category != null) 'category': category,
      };
      final resp = await _api.get('/reports/', queryParameters: params);
      final data = resp.data;
      final results = (data is Map ? (data['results'] ?? []) : data) as List;
      final reports = results.map((r) => Report.fromJson(r)).toList();
      emit(CommunityLoaded(
        reports: reports,
        hasMore: data is Map && data['next'] != null,
        activeFilter: category,
      ));
    } catch (e) {
      emit(CommunityError('Failed to load community reports'));
    }
  }

  Future<void> vote(int reportId) async {
    final current = state;
    if (current is! CommunityLoaded) return;
    try {
      await _api.post('/reports/$reportId/vote/');
      final updated = current.reports.map((r) {
        if (r.id == reportId) {
          return Report(
            id: r.id, reporterId: r.reporterId, reporterName: r.reporterName,
            villageId: r.villageId, villageName: r.villageName,
            category: r.category, subCategory: r.subCategory,
            descriptionText: r.descriptionText, descriptionHindi: r.descriptionHindi,
            audioS3Key: r.audioS3Key, photoS3Key: r.photoS3Key,
            latitude: r.latitude, longitude: r.longitude,
            ward: r.ward, urgency: r.urgency, status: r.status,
            voteCount: r.voteCount + 1, clusterId: r.clusterId,
            aiConfidence: r.aiConfidence, isGramSabha: r.isGramSabha,
            hasVoted: true, createdAt: r.createdAt,
          );
        }
        return r;
      }).toList();
      emit(current.copyWith(reports: updated));
    } catch (_) {}
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! CommunityLoaded || !current.hasMore) return;
    _page++;
    try {
      final params = <String, dynamic>{
        'village': _villageId ?? 1,
        'ordering': '-vote_count',
        'page': _page,
        if (current.activeFilter != null) 'category': current.activeFilter,
      };
      final resp = await _api.get('/reports/', queryParameters: params);
      final data = resp.data;
      final results = (data is Map ? (data['results'] ?? []) : data) as List;
      final more = results.map((r) => Report.fromJson(r)).toList();
      emit(current.copyWith(
        reports: [...current.reports, ...more],
        hasMore: data is Map && data['next'] != null,
      ));
    } catch (_) {}
  }
}
