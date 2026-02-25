class Report {
  final int id;
  final int? reporterId;
  final String reporterName;
  final int villageId;
  final String villageName;
  final String category;
  final String subCategory;
  final String descriptionText;
  final String descriptionHindi;
  final String? audioS3Key;
  final String? photoS3Key;
  final double? latitude;
  final double? longitude;
  final int? ward;
  final String urgency;
  final String status;
  final int voteCount;
  final int? clusterId;
  final double? aiConfidence;
  final bool isGramSabha;
  final bool hasVoted;
  final DateTime createdAt;

  Report({
    required this.id, this.reporterId, this.reporterName = '',
    required this.villageId, this.villageName = '',
    this.category = '', this.subCategory = '',
    this.descriptionText = '', this.descriptionHindi = '',
    this.audioS3Key, this.photoS3Key,
    this.latitude, this.longitude, this.ward,
    this.urgency = 'medium', this.status = 'reported',
    this.voteCount = 0, this.clusterId,
    this.aiConfidence, this.isGramSabha = false,
    this.hasVoted = false, required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
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
    return Report(
      id: json['id'], reporterId: json['reporter'],
      reporterName: json['reporter_name'] ?? '',
      villageId: json['village'], villageName: json['village_name'] ?? '',
      category: json['category'] ?? '', subCategory: json['sub_category'] ?? '',
      descriptionText: json['description_text'] ?? '',
      descriptionHindi: json['description_hindi'] ?? '',
      audioS3Key: json['audio_s3_key'], photoS3Key: json['photo_s3_key'],
      latitude: lat, longitude: lng, ward: json['ward'],
      urgency: json['urgency'] ?? 'medium', status: json['status'] ?? 'reported',
      voteCount: json['vote_count'] ?? 0, clusterId: json['cluster'],
      aiConfidence: json['ai_confidence']?.toDouble(),
      isGramSabha: json['is_gram_sabha'] ?? false,
      hasVoted: json['has_voted'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
