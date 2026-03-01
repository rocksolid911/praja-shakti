import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import 'gram_sabha_state.dart';

class GramSabhaCubit extends Cubit<GramSabhaState> {
  final ApiClient _api;

  GramSabhaCubit(this._api) : super(GramSabhaInitial());

  Future<void> loadSessions({int villageId = 1}) async {
    emit(GramSabhaLoading());
    try {
      final resp = await _api.get('/gramsabha/', queryParameters: {'village': villageId});
      final data = resp.data;
      final results = (data is Map ? (data['results'] ?? []) : data) as List;
      emit(GramSabhaLoaded(results.map((s) => GramSabhaSession.fromJson(s)).toList()));
    } catch (e) {
      emit(GramSabhaError('Failed to load Gram Sabha sessions'));
    }
  }

  Future<void> createSession(String title, DateTime scheduled, int villageId) async {
    emit(GramSabhaLoading());
    try {
      await _api.post('/gramsabha/', data: {
        'village': villageId,
        'title': title,
        'scheduled_at': scheduled.toIso8601String(),
      });
      await loadSessions(villageId: villageId);
    } catch (e) {
      emit(GramSabhaError('Failed to create session'));
    }
  }

  Future<void> raiseIssue(int sessionId, String title) async {
    try {
      await _api.post('/gramsabha-issues/', data: {'title': title, 'session': sessionId});
      await loadSessions();
    } catch (e) {
      emit(GramSabhaError('Failed to raise issue'));
    }
  }

  Future<void> voteIssue(int sessionId, int issueId) async {
    try {
      await _api.post('/gramsabha-issues/$issueId/vote/', data: {});
    } catch (e) {
      emit(GramSabhaError('Failed to vote'));
    }
  }

  Future<void> endSession(int sessionId, int villageId) async {
    try {
      await _api.post('/gramsabha/$sessionId/end/', data: {});
      await loadSessions(villageId: villageId);
    } catch (e) {
      emit(GramSabhaError('Failed to end session'));
    }
  }
}
