import '../../../core/models/report.dart';

abstract class ReportState {}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportRecording extends ReportState {
  final Duration duration;
  ReportRecording(this.duration);
}

class ReportSubmitting extends ReportState {}

class ReportSubmitted extends ReportState {
  final Report report;
  ReportSubmitted(this.report);
}

class ReportLoaded extends ReportState {
  final Report report;
  ReportLoaded(this.report);
}

class ReportError extends ReportState {
  final String message;
  ReportError(this.message);
}

// ── Location cascade states ─────────────────────────────────────────────
// Full hierarchy: State → District → Gram Panchayat → Village → Ward

/// States are being fetched from the backend.
class LocationStatesLoading extends ReportState {}

/// States loaded; user must pick one.
class LocationStatesLoaded extends ReportState {
  final List<GeoOption> states;
  LocationStatesLoaded(this.states);
}

/// Districts loading after state selected.
class LocationDistrictsLoading extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  LocationDistrictsLoading(this.states, this.selectedState);
}

/// Districts loaded; user must pick one.
class LocationDistrictsLoaded extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  LocationDistrictsLoaded(this.states, this.selectedState, this.districts);
}

/// No GPs exist for this district — user must type GP + village name.
class LocationNoPanchayatsFound extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  LocationNoPanchayatsFound(
      this.states, this.selectedState, this.districts, this.selectedDistrict);
}

/// setup-location call in progress (creating new GP/Village).
class LocationSettingUp extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  LocationSettingUp(
      this.states, this.selectedState, this.districts, this.selectedDistrict);
}

/// Gram Panchayats (GPs) loading after district selected.
class LocationPanchayatsLoading extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  LocationPanchayatsLoading(
      this.states, this.selectedState, this.districts, this.selectedDistrict);
}

/// GPs loaded; user must pick one.
class LocationPanchayatsLoaded extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  final List<GeoOption> panchayats;
  LocationPanchayatsLoaded(this.states, this.selectedState, this.districts,
      this.selectedDistrict, this.panchayats);
}

/// Villages loading after GP selected.
class LocationVillagesLoading extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  final List<GeoOption> panchayats;
  final GeoOption selectedPanchayat;
  LocationVillagesLoading(this.states, this.selectedState, this.districts,
      this.selectedDistrict, this.panchayats, this.selectedPanchayat);
}

/// Villages loaded; user must pick one.
class LocationVillagesLoaded extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  final List<GeoOption> panchayats;
  final GeoOption selectedPanchayat;
  final List<GeoOption> villages;
  LocationVillagesLoaded(this.states, this.selectedState, this.districts,
      this.selectedDistrict, this.panchayats, this.selectedPanchayat,
      this.villages);
}

/// Village selected — provisioning data in background, ready to submit.
class LocationVillageSelected extends ReportState {
  final List<GeoOption> states;
  final GeoOption selectedState;
  final List<GeoOption> districts;
  final GeoOption selectedDistrict;
  final List<GeoOption> panchayats;
  final GeoOption selectedPanchayat;
  final List<GeoOption> villages;
  final GeoOption selectedVillage;
  final VillageDetails details;
  LocationVillageSelected(
      this.states,
      this.selectedState,
      this.districts,
      this.selectedDistrict,
      this.panchayats,
      this.selectedPanchayat,
      this.villages,
      this.selectedVillage,
      this.details);
}

// ── Data classes ───────────────────────────────────────────────────────

class GeoOption {
  final int id;
  final String name;
  const GeoOption({required this.id, required this.name});

  factory GeoOption.fromJson(Map<String, dynamic> j) =>
      GeoOption(id: j['id'] as int, name: j['name'] as String);
}

class VillageDetails {
  final int villageId;
  final String villageName;
  final int panchayatId;
  final String panchayatName;
  final int? districtId;
  final String districtName;
  final String stateName;
  final int fundAvailableInr;
  final int wardCount;
  final int? population;
  final int? households;
  final double? ndviScore;
  final double? groundwaterDepthM;
  final bool provisioning;

  const VillageDetails({
    required this.villageId,
    required this.villageName,
    required this.panchayatId,
    required this.panchayatName,
    this.districtId,
    required this.districtName,
    required this.stateName,
    required this.fundAvailableInr,
    this.wardCount = 9,
    this.population,
    this.households,
    this.ndviScore,
    this.groundwaterDepthM,
    required this.provisioning,
  });

  factory VillageDetails.fromJson(Map<String, dynamic> j) => VillageDetails(
        villageId: j['village_id'] as int,
        villageName: j['village_name'] as String,
        panchayatId: j['panchayat_id'] as int,
        panchayatName: j['panchayat_name'] as String,
        districtId: j['district_id'] as int?,
        districtName: j['district_name'] as String? ?? '',
        stateName: j['state_name'] as String? ?? '',
        fundAvailableInr: j['fund_available_inr'] as int? ?? 0,
        wardCount: j['ward_count'] as int? ?? 9,
        population: j['population'] as int?,
        households: j['households'] as int?,
        ndviScore: (j['ndvi_score'] as num?)?.toDouble(),
        groundwaterDepthM: (j['groundwater_depth_m'] as num?)?.toDouble(),
        provisioning: j['provisioning'] as bool? ?? false,
      );
}
