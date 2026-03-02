import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/report.dart';
import 'report_state.dart';

class ReportCubit extends Cubit<ReportState> {
  final ApiClient _api;

  ReportCubit(this._api) : super(ReportInitial());

  // ── Existing report operations ────────────────────────────────────────

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
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude]
          },
      };
      final resp = await _api.post('/reports/', data: data);
      emit(ReportSubmitted(Report.fromJson(resp.data)));
    } catch (e) {
      emit(ReportError(_parseError(e)));
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

  // ── Location cascade: State → District → GP → Village → Ward ─────────

  /// Pre-fill the location from the user's existing profile (skip cascade).
  /// Call this instead of [loadStates] when the user already has a village set.
  Future<void> loadUserLocation(int villageId) async {
    emit(LocationStatesLoading());
    try {
      final resp = await _api.post(
        '/map/provision-village/',
        data: {'village_id': villageId},
      );
      final details =
          VillageDetails.fromJson(resp.data as Map<String, dynamic>);
      final village =
          GeoOption(id: details.villageId, name: details.villageName);
      final panchayat =
          GeoOption(id: details.panchayatId, name: details.panchayatName);
      final districtOpt = GeoOption(
          id: details.districtId ?? 0, name: details.districtName);
      final stateOpt = GeoOption(id: 0, name: details.stateName);
      emit(LocationVillageSelected(
        [], stateOpt,
        [], districtOpt,
        [panchayat], panchayat,
        [village], village,
        details,
      ));
    } catch (_) {
      // Fallback to fresh cascade if provision fails
      await loadStates();
    }
  }

  /// Step 1: Load all Indian states. Call once when report screen opens.
  Future<void> loadStates() async {
    emit(LocationStatesLoading());
    try {
      final resp = await _api.get('/states/');
      final List<dynamic> raw = resp.data is List
          ? resp.data as List
          : (resp.data['results'] ?? resp.data['data'] ?? []) as List;
      final states =
          raw.map((j) => GeoOption.fromJson(j as Map<String, dynamic>)).toList();
      emit(LocationStatesLoaded(states));
    } catch (e) {
      emit(ReportError('Failed to load states: ${_parseError(e)}'));
    }
  }

  /// Step 2: Load districts for the selected state.
  void selectState(GeoOption state, List<GeoOption> allStates) {
    emit(LocationDistrictsLoading(allStates, state));
    _loadDistricts(state, allStates);
  }

  Future<void> _loadDistricts(
      GeoOption state, List<GeoOption> allStates) async {
    try {
      final resp =
          await _api.get('/districts/', queryParameters: {'state': state.id});
      final List<dynamic> raw = resp.data is List
          ? resp.data as List
          : (resp.data['results'] ?? resp.data['data'] ?? []) as List;
      final districts =
          raw.map((j) => GeoOption.fromJson(j as Map<String, dynamic>)).toList();
      emit(LocationDistrictsLoaded(allStates, state, districts));
    } catch (e) {
      emit(ReportError('Failed to load districts: ${_parseError(e)}'));
    }
  }

  /// Step 3: Load Gram Panchayats for the selected district.
  void selectDistrict(
    GeoOption district,
    List<GeoOption> allStates,
    GeoOption selectedState,
    List<GeoOption> allDistricts,
  ) {
    emit(LocationPanchayatsLoading(
        allStates, selectedState, allDistricts, district));
    _loadPanchayats(district, allStates, selectedState, allDistricts);
  }

  Future<void> _loadPanchayats(
    GeoOption district,
    List<GeoOption> allStates,
    GeoOption selectedState,
    List<GeoOption> allDistricts,
  ) async {
    try {
      final resp = await _api
          .get('/panchayats/', queryParameters: {'district': district.id});
      final List<dynamic> raw = resp.data is List
          ? resp.data as List
          : (resp.data['results'] ?? resp.data['data'] ?? []) as List;
      final panchayats =
          raw.map((j) => GeoOption.fromJson(j as Map<String, dynamic>)).toList();
      if (panchayats.isEmpty) {
        // No pre-loaded GPs for this district — let user type one
        emit(LocationNoPanchayatsFound(allStates, selectedState, allDistricts, district));
      } else {
        emit(LocationPanchayatsLoaded(
            allStates, selectedState, allDistricts, district, panchayats));
      }
    } catch (e) {
      emit(ReportError('Failed to load panchayats: ${_parseError(e)}'));
    }
  }

  /// Called when user manually types GP + village name for an unlisted district.
  Future<void> setupNewLocation({
    required int districtId,
    required String panchayatName,
    required String villageName,
    required List<GeoOption> allStates,
    required GeoOption selectedState,
    required List<GeoOption> allDistricts,
    required GeoOption selectedDistrict,
  }) async {
    emit(LocationSettingUp(allStates, selectedState, allDistricts, selectedDistrict));
    try {
      // Create GP + Village on the backend
      final setupResp = await _api.post('/locations/setup-location/', data: {
        'district_id': districtId,
        'panchayat_name': panchayatName,
        'village_name': villageName,
      });
      final d = setupResp.data as Map<String, dynamic>;
      final panchayat = GeoOption(id: d['panchayat_id'] as int, name: d['panchayat_name'] as String);
      final village = GeoOption(id: d['village_id'] as int, name: d['village_name'] as String);

      // Provision the village so map/dashboard layers get background data
      final details = VillageDetails(
        villageId: d['village_id'] as int,
        villageName: d['village_name'] as String,
        panchayatId: d['panchayat_id'] as int,
        panchayatName: d['panchayat_name'] as String,
        districtName: d['district_name'] as String? ?? '',
        stateName: d['state_name'] as String? ?? '',
        fundAvailableInr: (d['fund_available_inr'] as int?) ?? 0,
        wardCount: (d['ward_count'] as int?) ?? 9,
        provisioning: true,
      );
      emit(LocationVillageSelected(
        allStates, selectedState, allDistricts, selectedDistrict,
        [panchayat], panchayat, [village], village, details,
      ));
    } catch (e) {
      emit(ReportError('Failed to set up location: ${_parseError(e)}'));
    }
  }

  /// Step 4: Load villages for the selected Gram Panchayat.
  void selectPanchayat(
    GeoOption panchayat,
    List<GeoOption> allStates,
    GeoOption selectedState,
    List<GeoOption> allDistricts,
    GeoOption selectedDistrict,
    List<GeoOption> allPanchayats,
  ) {
    emit(LocationVillagesLoading(allStates, selectedState, allDistricts,
        selectedDistrict, allPanchayats, panchayat));
    _loadVillages(panchayat, allStates, selectedState, allDistricts,
        selectedDistrict, allPanchayats);
  }

  Future<void> _loadVillages(
    GeoOption panchayat,
    List<GeoOption> allStates,
    GeoOption selectedState,
    List<GeoOption> allDistricts,
    GeoOption selectedDistrict,
    List<GeoOption> allPanchayats,
  ) async {
    try {
      final resp = await _api
          .get('/villages/', queryParameters: {'panchayat': panchayat.id});
      final List<dynamic> raw = resp.data is List
          ? resp.data as List
          : (resp.data['results'] ?? resp.data['data'] ?? []) as List;
      final villages =
          raw.map((j) => GeoOption.fromJson(j as Map<String, dynamic>)).toList();
      emit(LocationVillagesLoaded(allStates, selectedState, allDistricts,
          selectedDistrict, allPanchayats, panchayat, villages));
    } catch (e) {
      emit(ReportError('Failed to load villages: ${_parseError(e)}'));
    }
  }

  /// Step 5: Select a village — triggers backend provision, updates user profile.
  Future<void> selectVillage(
    GeoOption village,
    List<GeoOption> allStates,
    GeoOption selectedState,
    List<GeoOption> allDistricts,
    GeoOption selectedDistrict,
    List<GeoOption> allPanchayats,
    GeoOption selectedPanchayat,
    List<GeoOption> allVillages,
  ) async {
    try {
      final resp = await _api.post(
        '/map/provision-village/',
        data: {'village_id': village.id},
      );
      final details = VillageDetails.fromJson(resp.data as Map<String, dynamic>);
      emit(LocationVillageSelected(
        allStates,
        selectedState,
        allDistricts,
        selectedDistrict,
        allPanchayats,
        selectedPanchayat,
        allVillages,
        village,
        details,
      ));
    } catch (e) {
      // Even if provision fails, allow selection with minimal details
      emit(LocationVillageSelected(
        allStates,
        selectedState,
        allDistricts,
        selectedDistrict,
        allPanchayats,
        selectedPanchayat,
        allVillages,
        village,
        VillageDetails(
          villageId: village.id,
          villageName: village.name,
          panchayatId: selectedPanchayat.id,
          panchayatName: selectedPanchayat.name,
          districtName: selectedDistrict.name,
          stateName: selectedState.name,
          fundAvailableInr: 0,
          wardCount: 9,
          provisioning: true,
        ),
      ));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _parseError(dynamic e) {
    if (e is DioException && e.response != null) {
      final data = e.response!.data;
      if (data is Map) return data.values.first?.toString() ?? 'Server error';
      return 'Server error ${e.response!.statusCode}';
    }
    return e.toString();
  }
}
