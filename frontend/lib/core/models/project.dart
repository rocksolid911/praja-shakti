class Project {
  final int id;
  final int? clusterId;
  final int villageId;
  final String villageName;
  final String title;
  final String description;
  final String category;
  final int estimatedCostInr;
  final int? beneficiaryCount;
  final Map<String, dynamic>? impactProjection;
  final double? priorityScore;
  final double? aiConfidence;
  final String status;
  final double? avgCitizenRating;
  final DateTime? adoptedAt;
  final DateTime? startedAt;
  final String? expectedCompletion;
  final DateTime? completedAt;
  final DateTime createdAt;
  final List<FundPlan> fundPlans;
  final String? proposalDownloadUrl;
  final double? lat;
  final double? lng;

  Project({
    required this.id, this.clusterId, required this.villageId,
    this.villageName = '', required this.title, this.description = '',
    this.category = '', required this.estimatedCostInr,
    this.beneficiaryCount, this.impactProjection,
    this.priorityScore, this.aiConfidence, this.status = 'recommended',
    this.avgCitizenRating, this.adoptedAt, this.startedAt,
    this.expectedCompletion, this.completedAt, required this.createdAt,
    this.fundPlans = const [],
    this.proposalDownloadUrl, this.lat, this.lng,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'], clusterId: json['cluster'],
    villageId: json['village'], villageName: json['village_name'] ?? '',
    title: json['title'] ?? '', description: json['description'] ?? '',
    category: json['category'] ?? '', estimatedCostInr: json['estimated_cost_inr'] ?? 0,
    beneficiaryCount: json['beneficiary_count'],
    impactProjection: json['impact_projection'],
    priorityScore: json['priority_score']?.toDouble(),
    aiConfidence: json['ai_confidence']?.toDouble(),
    status: json['status'] ?? 'recommended',
    avgCitizenRating: json['avg_citizen_rating']?.toDouble(),
    adoptedAt: json['adopted_at'] != null ? DateTime.parse(json['adopted_at']) : null,
    startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
    expectedCompletion: json['expected_completion'],
    completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    createdAt: DateTime.parse(json['created_at']),
    fundPlans: (json['fund_plans'] as List?)?.map((e) => FundPlan.fromJson(e)).toList() ?? [],
    proposalDownloadUrl: json['proposal_download_url'],
    lat: json['lat']?.toDouble(),
    lng: json['lng']?.toDouble(),
  );
}

class FundPlan {
  final int totalCostInr;
  final int panchayatContributionInr;
  final double savingsPct;
  final List<SchemeUsed> schemesUsed;

  FundPlan({required this.totalCostInr, required this.panchayatContributionInr,
    required this.savingsPct, this.schemesUsed = const []});

  factory FundPlan.fromJson(Map<String, dynamic> json) => FundPlan(
    totalCostInr: json['total_cost_inr'] ?? 0,
    panchayatContributionInr: json['panchayat_contribution_inr'] ?? 0,
    savingsPct: (json['savings_pct'] ?? 0).toDouble(),
    schemesUsed: (json['schemes_used'] as List?)?.map((e) => SchemeUsed.fromJson(e)).toList() ?? [],
  );
}

class SchemeUsed {
  final String schemeName;
  final int amountInr;
  final double pctCovered;

  SchemeUsed({required this.schemeName, required this.amountInr, required this.pctCovered});

  factory SchemeUsed.fromJson(Map<String, dynamic> json) => SchemeUsed(
    schemeName: json['scheme_name'] ?? '', amountInr: json['amount_inr'] ?? 0,
    pctCovered: (json['pct_covered'] ?? 0).toDouble(),
  );
}
