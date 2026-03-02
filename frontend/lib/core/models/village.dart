class Village {
  final int id;
  final String name;
  final String lgdCode;
  final int? panchayatId;
  final String? panchayatName;
  final String? districtName;
  final String? stateName;
  final double? latitude;
  final double? longitude;
  final int? population;
  final int? households;
  final int? agriculturalHouseholds;
  final double? groundwaterDepthM;
  final double? ndviScore;

  Village({
    required this.id, required this.name, required this.lgdCode,
    this.panchayatId, this.panchayatName, this.districtName, this.stateName,
    this.latitude, this.longitude, this.population, this.households,
    this.agriculturalHouseholds, this.groundwaterDepthM, this.ndviScore,
  });

  factory Village.fromJson(Map<String, dynamic> json) {
    double? lat, lng;
    if (json['location'] != null) {
      final loc = json['location'];
      if (loc is Map) {
        final coords = loc['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          lng = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      }
    }
    return Village(
      id: json['id'], name: json['name'] ?? '', lgdCode: json['lgd_code'] ?? '',
      panchayatId: json['panchayat'], panchayatName: json['panchayat_name'],
      districtName: json['district_name'], stateName: json['state_name'],
      latitude: lat, longitude: lng,
      population: json['population'], households: json['households'],
      agriculturalHouseholds: json['agricultural_households'],
      groundwaterDepthM: json['groundwater_depth_m']?.toDouble(),
      ndviScore: json['ndvi_score']?.toDouble(),
    );
  }
}
