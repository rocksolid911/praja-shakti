import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import 'scheme_state.dart';

class SchemeCubit extends Cubit<SchemeState> {
  final ApiClient _api;
  final List<SchemeMessage> _history = [];

  SchemeCubit(this._api) : super(SchemeInitial());

  Future<void> query(String text, {int villageId = 1}) async {
    _history.add(SchemeMessage(text: text, isUser: true));
    emit(SchemeLoading());
    try {
      final resp = await _api.post('/ai/scheme-query/', data: {
        'query': text,
        'village_id': villageId,
      });
      final data = resp.data;
      final answer = data['answer']?.toString() ?? 'No answer available';
      final rawSources = (data['sources'] as List?) ?? [];
      final sources = rawSources.map<Map<String, String>>((s) => {
        'scheme': s['scheme']?.toString() ?? '',
        'section': s['section']?.toString() ?? '',
      }).toList();

      _history.add(SchemeMessage(text: answer, isUser: false, sources: sources));
      emit(SchemeQueryResult(
        query: text,
        answer: answer,
        sources: sources,
        history: List.unmodifiable(_history),
      ));
    } catch (e) {
      final errMsg = 'माफ़ करें, अभी उत्तर देना संभव नहीं। कृपया दोबारा प्रयास करें।';
      _history.add(SchemeMessage(text: errMsg, isUser: false));
      emit(SchemeQueryResult(
        query: text, answer: errMsg, sources: [],
        history: List.unmodifiable(_history),
      ));
    }
  }

  void clearHistory() {
    _history.clear();
    emit(SchemeInitial());
  }
}
