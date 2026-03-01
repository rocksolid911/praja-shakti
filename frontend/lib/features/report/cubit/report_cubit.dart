import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import 'report_state.dart';

class ReportCubit extends Cubit<ReportState> {
  final ApiClient _api;

  ReportCubit(this._api) : super(ReportInitial());

  Future<void> loadReport(int reportId) async {
    emit(ReportLoading());
    try {
      final resp = await _api.get('/reports/$reportId/');
      emit(ReportLoaded(Report.fromJson(resp.data)));
    } catch (e) {
      emit(ReportError('Failed to load report'));
    }
  }

  Future<void> submitTextReport({
    required int villageId,
    required String description,
    required String category,
    required String urgency,
    double? latitude,
    double? longitude,
    int? ward,
  }) async {
    emit(ReportSubmitting());
    try {
      final data = <String, dynamic>{
        'village': villageId,
        'description_text': description,
        'category': category,
        'urgency': urgency,
        if (ward != null) 'ward': ward,
        if (latitude != null && longitude != null)
          'location': {'type': 'Point', 'coordinates': [longitude, latitude]},
      };
      final resp = await _api.post('/reports/', data: data);
      emit(ReportSubmitted(Report.fromJson(resp.data)));
    } catch (e) {
      String msg = 'Failed to submit report. Please try again.';
      if (e is DioException && e.response != null) {
        final data = e.response!.data;
        if (data is Map) {
          msg = data.values.first?.toString() ?? msg;
        } else {
          msg = 'Server error ${e.response!.statusCode}';
        }
      }
      emit(ReportError(msg));
    }
  }

  Future<void> vote(int reportId) async {
    try {
      await _api.post('/reports/$reportId/vote/');
      await loadReport(reportId);
    } catch (e) {
      emit(ReportError('Failed to vote'));
    }
  }

  Future<void> removeVote(int reportId) async {
    try {
      await _api.delete('/reports/$reportId/vote/');
      await loadReport(reportId);
    } catch (e) {
      emit(ReportError('Failed to remove vote'));
    }
  }
}
